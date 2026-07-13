module AdminAssistant
  # Turns a Customer into compact, token-cheap hashes for tool output. Keeping
  # this in one place means every tool describes a lead the same way.
  module CustomerPresenter
    module_function

    # One-line-ish summary used in list results.
    def summary(c)
      {
        id: c.id,
        name: c.name,
        company: c.company.presence,
        status: c.status,
        lead_score: c.lead_score,
        country: c.country.presence,
        assigned_to: c.user&.name,
        reachable_by: reachable_channels(c),
        last_call_attempt: c.last_call_attempt_at&.to_date&.to_s,
        days_since_contact: days_since_contact(c)
      }.compact
    end

    # Fuller record for get_customer — profile plus recent context.
    def detail(c)
      summary(c).merge(
        email: c.email.presence,
        phone: c.phone.presence,
        lead_source: c.lead_source.presence,
        lead_score_reason: c.lead_score_reason.presence,
        preferred_calling_time: c.preferred_calling_time.presence,
        timezone: c.customer_location&.timezone || c.timezone.presence,
        call_stats: "#{c.successful_call_attempts.to_i} connected / #{c.total_call_attempts.to_i} attempts",
        followup_date: c.followup_date&.to_date&.to_s,
        notes: [c.notes.presence, c.followup_notes.presence].compact.join(" | ").presence,
        project: c.idea_description.to_s.strip[0, 500].presence,
        deals: deals(c),
        recent_messages: recent_messages(c),
        open_tasks: open_tasks(c)
      ).compact
    end

    # Channels we could actually reach this lead on right now.
    def reachable_channels(c)
      channels = []
      channels << "phone" if c.phone.present? && c.call_status != "Incorrect Number"
      channels << "email" if c.email.present? && c.email_status != "Incorrect Email"
      channels << "whatsapp" if c.whatsapp_chat_id.present? && !c.whatsapp_phone_unreachable?
      channels
    end

    # Days since the last outbound call attempt (our best single recency signal).
    def days_since_contact(c)
      return nil if c.last_call_attempt_at.blank?
      ((Time.current - c.last_call_attempt_at) / 1.day).floor
    end

    def deals(c)
      c.deals.includes(:deal_stage).order(created_at: :desc).limit(5).map do |d|
        {
          title: d.title.presence || "Deal ##{d.id}",
          status: d.status,
          stage: (d.deal_stage&.name rescue nil),
          amount: d.amount.present? ? d.amount.to_i : nil
        }.compact
      end
    end

    # Both WhatsApp channels merged, newest-first, capped small for token budget.
    def recent_messages(c)
      turns = []
      c.messages.order(created_at: :desc).limit(8).each { |m| turns << { at: m.created_at, dir: m.direction, text: m.content } }
      c.whatsapp_messages.order(created_at: :desc).limit(8).each { |m| turns << { at: m.created_at, dir: m.direction, text: m.body } }
      turns.reject! { |t| t[:text].to_s.strip.blank? }
      turns.sort_by { |t| t[:at] || Time.at(0) }.last(10).map do |t|
        { who: t[:dir].to_s == "inbound" ? "them" : "us", text: t[:text].to_s.strip[0, 300] }
      end
    end

    def open_tasks(c)
      c.tasks.where.not(status: "completed").order(due_date: :asc).limit(5).map do |t|
        { title: (t.try(:title).presence || "Task ##{t.id}"), due: t.due_date&.to_date&.to_s }.compact
      end
    end
  end
end
