# Builds a comprehensive plain-text dossier of everything we know about a
# customer — profile, deals, tasks, activity, the full WhatsApp/text history,
# emails, and every call transcript — so it can be dropped into a Proposal
# Generator chat as context. Read-only. Bounded so a huge history can't blow
# past the model's context window.
class CustomerDossierService
  MAX_CHARS = 24_000

  def initialize(customer)
    @c = customer
  end

  def build
    sections = []
    sections << profile
    sections << "LEAD SCORE: #{@c.lead_score} — #{@c.lead_score_reason}" if @c.lead_score.present?
    sections << "PROJECT / IDEA:\n#{@c.idea_description}" if @c.idea_description.present?
    sections << "NOTES:\n#{notes}" if notes.present?
    sections << "DEALS:\n#{deals}" if deals.present?
    sections << "OPEN TASKS:\n#{tasks}" if tasks.present?
    sections << "RECENT ACTIVITY:\n#{activities}" if activities.present?
    sections << "WHATSAPP / TEXT HISTORY (Them = customer, Us = us):\n#{messages}" if messages.present?
    sections << "EMAILS (Them = customer, Us = us):\n#{emails}" if emails.present?
    sections << "CALL TRANSCRIPTS:\n#{transcripts}" if transcripts.present?
    sections.compact.join("\n\n")[0, MAX_CHARS]
  end

  # One-line label for the UI chip.
  def label
    parts = [@c.name.presence || "Customer ##{@c.id}"]
    parts << @c.company if @c.company.present?
    parts.join(" · ")
  end

  private

  def profile
    <<~P.strip
      CUSTOMER PROFILE
      Name: #{@c.name}
      Company: #{@c.company.presence || "(unknown)"}
      Email: #{@c.email.presence || "(none)"}
      Phone: #{@c.phone.presence || "(none)"}
      Country: #{@c.country.presence || "(unknown)"}
      Status: #{@c.status.presence || "(none)"}
      Lead source: #{@c.lead_source.presence || "(unknown)"}
      Calls: #{@c.successful_call_attempts.to_i} connected of #{@c.total_call_attempts.to_i} attempts
    P
  end

  def notes
    [@c.notes.presence, @c.followup_notes.presence].compact.join("\n")
  end

  def deals
    @c.deals.includes(:deal_stage).order(created_at: :desc).filter_map do |d|
      stage = (d.deal_stage&.name rescue nil)
      amount = d.amount.present? ? " — $#{d.amount.to_i}" : ""
      "• #{d.try(:title).presence || "Deal ##{d.id}"} (#{d.status}#{stage ? ", #{stage}" : ""})#{amount}"
    end.join("\n")
  rescue
    nil
  end

  def tasks
    @c.tasks.where.not(status: "completed").order(due_date: :asc).limit(20).filter_map do |t|
      due = t.due_date.present? ? " (due #{t.due_date.to_date})" : ""
      "• #{t.try(:title).presence || "Task ##{t.id}"}#{due}"
    end.join("\n")
  rescue
    nil
  end

  def activities
    @c.customer_activities.order(created_at: :desc).limit(20).filter_map do |a|
      text = a.try(:action).presence || a.try(:description).presence
      next if text.blank?
      details = a.try(:details).presence
      "• #{a.created_at.to_date}: #{[text, details].compact.join(' — ')}"
    end.join("\n")
  rescue
    nil
  end

  # Both WhatsApp channels merged, chronological.
  def messages
    turns = []
    @c.messages.order(created_at: :desc).limit(80).each { |m| turns << { at: m.created_at, dir: m.direction, text: m.content } }
    @c.whatsapp_messages.order(created_at: :desc).limit(80).each { |m| turns << { at: m.created_at, dir: m.direction, text: m.body } }
    turns.reject! { |t| t[:text].to_s.strip.blank? }
    return nil if turns.empty?
    turns.sort_by { |t| t[:at] || Time.at(0) }.last(120).map do |t|
      who = t[:dir].to_s == "inbound" ? "Them" : "Us"
      "#{who}: #{t[:text].to_s.strip}"
    end.join("\n")
  rescue
    nil
  end

  def emails
    return nil unless @c.respond_to?(:emails)
    @c.emails.order(created_at: :desc).limit(20).filter_map do |e|
      subject = e.try(:subject)
      body = e.try(:snippet).presence || e.try(:body_text).presence || e.try(:body_html)
      next if subject.blank? && body.blank?
      who = e.try(:from_email).to_s.casecmp?(@c.email.to_s) ? "Them" : "Us"
      clean = body.to_s.gsub(/<[^>]+>/, " ").gsub(/\s+/, " ").strip[0, 500]
      "#{who} | #{subject.to_s.strip}: #{clean}".strip
    end.reverse.join("\n---\n")
  rescue
    nil
  end

  # Every transcribed call.
  def transcripts
    @c.recordings.order(created_at: :desc).filter_map do |r|
      next unless r.respond_to?(:transcription) && r.transcription.present?
      "[#{r.created_at.to_date}]\n#{r.transcription.to_s.strip}"
    end.join("\n---\n").presence
  rescue
    nil
  end
end
