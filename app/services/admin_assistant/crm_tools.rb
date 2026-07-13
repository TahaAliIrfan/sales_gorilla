module AdminAssistant
  # The read-only toolbelt the admin assistant calls into. One class so the
  # LLM sees short, flat function names (crm__search_customers, etc.) rather
  # than langchainrb's long namespaced default (which weaker models mangle).
  #
  # Every method returns plain JSON-serializable data and NEVER writes.
  class CrmTools
    extend Langchain::ToolDefinition

    # Short prefix -> function names like "crm__list_stale_leads".
    def self.tool_name
      "crm"
    end

    # Statuses that mean "don't bother reaching out again".
    TERMINAL_STATUSES = ["Converted", "Not Interested", "Invalid", "Exhausted", "Exhausted_1"].freeze

    # --- search_customers ----------------------------------------------------
    define_function :search_customers,
      description: "Search customers/leads by name, email, phone or company, with optional status/country/assigned-rep filters. Returns a compact list. Use get_customer for the full record." do
      property :query, type: "string", description: "free-text: matches name, email, phone, or company", required: false
      property :status, type: "string", description: "exact lead status, e.g. 'Lead', 'Proposal Sent', 'Contact Established'", required: false
      property :country, type: "string", description: "country name to filter by", required: false
      property :assigned_to, type: "string", description: "name or email of the assigned rep", required: false
      property :limit, type: "string", description: "max rows to return as a number (default 25, max 50)", required: false
    end

    def search_customers(query: nil, status: nil, country: nil, assigned_to: nil, limit: 25)
      limit = clamp(limit, 25, 50)
      scope = Customer.includes(:user).all
      scope = scope.search(query) if query.present?
      scope = scope.where(status: status) if status.present?
      scope = scope.where("LOWER(country) = ?", country.downcase.strip) if country.present?
      if assigned_to.present?
        rep = User.where("LOWER(name) LIKE :q OR LOWER(email) LIKE :q", q: "%#{assigned_to.downcase.strip}%").first
        scope = rep ? scope.where(user_id: rep.id) : scope.none
      end

      rows = scope.order(Arel.sql("lead_score DESC NULLS LAST"), created_at: :desc).limit(limit)
      { count: rows.size, customers: rows.map { |c| CustomerPresenter.summary(c) } }
    rescue => e
      { error: e.message }
    end

    # --- get_customer --------------------------------------------------------
    define_function :get_customer,
      description: "Get the full record for one customer by id: profile, deals, recent WhatsApp/text history, and open tasks." do
      property :id, type: "string", description: "the customer id as a number", required: true
    end

    def get_customer(id:)
      customer = Customer.includes(:user, :customer_location).find_by(id: id)
      return { error: "No customer with id #{id}" } unless customer

      CustomerPresenter.detail(customer)
    rescue => e
      { error: e.message }
    end

    # --- list_stale_leads ----------------------------------------------------
    # Recency note: there is no single "last contacted" column, so we approximate
    # with last_call_attempt_at (our most reliable outbound signal). A lead with
    # a future follow-up already scheduled is excluded.
    define_function :list_stale_leads,
      description: "Find leads worth re-engaging: still open (not converted/dead), reachable by phone/email/whatsapp, and not contacted in the last N days. Ranked by lead score. Answers 'which leads can I still reach out to?'." do
      property :days, type: "string", description: "stale if not contacted in this many days as a number (default 30)", required: false
      property :min_lead_score, type: "string", description: "only include leads scoring at least this number (0-100)", required: false
      property :status, type: "string", description: "restrict to one status, e.g. 'Proposal Sent'", required: false
      property :limit, type: "string", description: "max leads to return as a number (default 20, max 50)", required: false
    end

    def list_stale_leads(days: 30, min_lead_score: nil, status: nil, limit: 20)
      days = [days.to_i, 0].max
      limit = clamp(limit, 20, 50)
      cutoff = days.days.ago

      scope = Customer.includes(:user)
                      .where.not(status: TERMINAL_STATUSES)
                      .where("(phone IS NOT NULL AND phone <> '') OR (email IS NOT NULL AND email <> '')")
                      .where("last_call_attempt_at IS NULL OR last_call_attempt_at < ?", cutoff)
                      .where("followup_date IS NULL OR followup_date < ?", Time.current)
      scope = scope.where(status: status) if status.present?
      scope = scope.where("lead_score >= ?", min_lead_score.to_i) if min_lead_score.present?

      rows = scope.order(Arel.sql("lead_score DESC NULLS LAST"), created_at: :asc).limit(limit)
      {
        criteria: { not_contacted_in_days: days, min_lead_score: min_lead_score, status: status }.compact,
        count: rows.size,
        leads: rows.map { |c| CustomerPresenter.summary(c) }
      }
    rescue => e
      { error: e.message }
    end

    # --- search_transcripts --------------------------------------------------
    define_function :search_transcripts,
      description: "Search call recording transcripts for a phrase (e.g. 'budget', 'not now', a competitor name). Returns matching customers with a snippet around the match." do
      property :term, type: "string", description: "word or phrase to find in call transcripts", required: true
      property :limit, type: "string", description: "max matches as a number (default 15, max 30)", required: false
    end

    def search_transcripts(term:, limit: 15)
      return { error: "term is required" } if term.to_s.strip.blank?
      limit = clamp(limit, 15, 30)

      rows = Recording.includes(:customer)
                      .where(transcription_status: "completed")
                      .where("transcription ILIKE ?", "%#{term.strip}%")
                      .order(created_at: :desc)
                      .limit(limit)
      {
        term: term,
        count: rows.size,
        matches: rows.map do |r|
          { customer_id: r.customer_id, customer: r.customer&.name,
            called_on: r.created_at&.to_date&.to_s, snippet: snippet(r.transcription, term) }.compact
        end
      }
    rescue => e
      { error: e.message }
    end

    # --- sales_summary -------------------------------------------------------
    define_function :sales_summary,
      description: "Sales/pipeline rollups: deal counts and value by status (active/won/lost), open value by stage, and won value by rep. Scope with a named period OR an explicit date range." do
      property :period, type: "string", description: "named period: all, today, this_week, this_month, last_month, this_quarter, last_quarter, this_year, last_year, ytd (default all)", required: false
      property :start_date, type: "string", description: "start date YYYY-MM-DD for a custom range (overrides period)", required: false
      property :end_date, type: "string", description: "end date YYYY-MM-DD for a custom range (defaults to today if only start_date given)", required: false
    end

    def sales_summary(period: "all", start_date: nil, end_date: nil)
      scope = Deal.all
      range = date_range(start_date, end_date) || period_range(period)
      scope = scope.where(created_at: range) if range

      by_status = scope.group(:status).count
      amt_by_status = scope.group(:status).sum(:amount)
      {
        period: (start_date.present? || end_date.present?) ? "custom" : period,
        range: range ? { from: range.first.to_date.to_s, to: range.last.to_date.to_s } : "all time",
        totals: {
          deals: scope.count,
          active: { count: by_status["active"].to_i, value: amt_by_status["active"].to_i },
          won: { count: by_status["won"].to_i, value: amt_by_status["won"].to_i },
          lost: { count: by_status["lost"].to_i, value: amt_by_status["lost"].to_i }
        },
        open_value_by_stage: open_value_by_stage(scope),
        won_value_by_rep: won_value_by_rep(scope)
      }
    rescue => e
      { error: e.message }
    end

    private

    def clamp(n, default, max)
      n = n.to_i
      n = default if n <= 0
      [n, max].min
    end

    def snippet(text, term)
      return nil if text.blank?
      idx = text.downcase.index(term.downcase)
      return text[0, 200] if idx.nil?
      from = [idx - 70, 0].max
      "…#{text[from, 200].to_s.strip}…"
    end

    # No caps: the number of stages and reps is small and bounded, so return the
    # full breakdown rather than hiding rows behind a top-N.
    def open_value_by_stage(scope)
      scope.where(status: "active").joins(:deal_stage).group("deal_stages.name").sum(:amount)
           .transform_values(&:to_i).sort_by { |_s, v| -v }.to_h
    rescue
      {}
    end

    def won_value_by_rep(scope)
      scope.where(status: "won").joins(:user).group("users.name").sum(:amount)
           .transform_values(&:to_i).sort_by { |_r, v| -v }.to_h
    rescue
      {}
    end

    # Explicit date range (YYYY-MM-DD). If only a start is given, run through
    # today; if only an end is given, treat it as everything up to that date.
    def date_range(start_date, end_date)
      return nil if start_date.blank? && end_date.blank?
      from = parse_date(start_date) || Time.at(0).to_date
      to   = parse_date(end_date) || Date.current
      from.beginning_of_day..to.end_of_day
    rescue
      nil
    end

    def parse_date(value)
      return nil if value.blank?
      Date.parse(value.to_s)
    rescue
      nil
    end

    def period_range(period)
      case period.to_s
      when "today"        then Time.current.beginning_of_day..Time.current.end_of_day
      when "this_week"    then Time.current.beginning_of_week..Time.current.end_of_week
      when "this_month"   then Time.current.beginning_of_month..Time.current.end_of_month
      when "last_month"   then 1.month.ago.beginning_of_month..1.month.ago.end_of_month
      when "this_quarter" then Time.current.beginning_of_quarter..Time.current.end_of_quarter
      when "last_quarter" then 3.months.ago.beginning_of_quarter..3.months.ago.end_of_quarter
      when "this_year"    then Time.current.beginning_of_year..Time.current.end_of_year
      when "last_year"    then 1.year.ago.beginning_of_year..1.year.ago.end_of_year
      when "ytd"          then Time.current.beginning_of_year..Time.current.end_of_day
      end
    end
  end
end
