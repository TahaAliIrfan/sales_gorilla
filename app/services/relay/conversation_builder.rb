module Relay
  # Merges a customer's multi-channel history (WhatsApp, email, calls, notes,
  # and timeline micro-events) into one chronologically-ordered stream for the
  # Relay lead workspace (docs/design/relay-app/project/app/view-lead.jsx).
  #
  # Each source is bounded to its most-recent N rows so the page stays fast on
  # leads with thousands of messages; "load older" can lift the bound later.
  # Events are normalized into lightweight structs with a common :at timestamp,
  # then sorted ascending so the newest sits at the bottom of the canvas.
  class ConversationBuilder
    Event = Struct.new(:kind, :at, :record, keyword_init: true)

    # Per-source caps. WhatsApp threads are the densest, so they get the most
    # headroom; everything else is comfortably bounded.
    LIMITS = {
      whatsapp: 200,
      email:    40,
      call:     40,
      activity: 60
    }.freeze

    # CustomerActivity actions that are already represented by a richer event
    # (calls, emails) or that are pure noise on the canvas. Everything else
    # surfaces as a small system micro-event.
    SUPPRESSED_ACTIVITY = [
      "Call Recording", "email_received", "email_sent",
      # A runaway analysis job wrote tens of millions of these per org; they
      # carry no conversational meaning and would drown the recent window.
      "Phone Analysis Failed"
    ].freeze

    def initialize(customer)
      @customer = customer
    end

    # Returns events ascending by time, ready to render. Date separators are
    # injected by the view as it walks the list (so the same list can be
    # re-grouped without rebuilding).
    def events
      (whatsapp_events + email_events + call_events + activity_events)
        .sort_by { |e| [ e.at, e.kind.to_s ] }
    end

    private

    def whatsapp_events
      @customer.whatsapp_messages
               .order(Arel.sql("COALESCE(timestamp, created_at) DESC"))
               .limit(LIMITS[:whatsapp])
               .to_a
               .map { |m| Event.new(kind: :whatsapp, at: (m.timestamp || m.created_at), record: m) }
    end

    def email_events
      @customer.emails
               .with_attached_attachments
               .order(Arel.sql("COALESCE(sent_at, received_at, created_at) DESC"))
               .limit(LIMITS[:email])
               .to_a
               .map { |e| Event.new(kind: :email, at: (e.sent_at || e.received_at || e.created_at), record: e) }
    end

    def call_events
      @customer.recordings
               .includes(audio_file_attachment: :blob)
               .order(Arel.sql("COALESCE(date, created_at) DESC"))
               .limit(LIMITS[:call])
               .to_a
               .map { |r| Event.new(kind: :call, at: (r.date || r.created_at), record: r) }
    end

    # Notes (action: "note") render as note cards; the remaining un-suppressed
    # activities render as compact system rows.
    def activity_events
      @customer.customer_activities
               .order(created_at: :desc)
               .limit(LIMITS[:activity])
               .to_a
               .reject { |a| SUPPRESSED_ACTIVITY.include?(a.action) }
               .map do |a|
                 kind = a.action == "note" ? :note : :activity
                 Event.new(kind: kind, at: a.created_at, record: a)
               end
    end
  end
end
