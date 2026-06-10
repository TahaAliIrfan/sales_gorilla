# Enriches a MetaInboundLead (created by the webhook) into a Customer.
#
# The webhook only gives us ids, so here we call the Graph API with the page's
# stored access token to fetch the lead's field_data, map the standard fields
# onto a Customer, append any custom form questions to the customer notes, and
# keep the full raw field_data on the lead row.
#
# Runs on the root webhook host where no tenant is set, so we re-establish the
# org from the lead before touching any tenant-scoped record.
class ProcessMetaInboundLeadWorker
  include Sidekiq::Worker
  sidekiq_options queue: "followups", retry: 5

  # Meta's standard lead-form fields; everything else is a custom question that
  # we preserve in the customer notes rather than dropping.
  STANDARD_FIELDS = %w[full_name first_name last_name email phone_number].freeze

  def perform(lead_id)
    lead = ActsAsTenant.without_tenant { MetaInboundLead.find_by(id: lead_id) }
    return unless lead
    return unless lead.status == "received"

    ActsAsTenant.with_tenant(lead.organization) { process(lead) }
  end

  private

  def process(lead)
    connection = MetaPageConnection.active.find_by(page_id: lead.page_id)
    if connection.nil? || connection.page_access_token.blank?
      return lead.mark_failed!("No active page connection / token for page #{lead.page_id}")
    end

    result = MetaLeadAdsService.fetch_lead(
      leadgen_id: lead.leadgen_id,
      page_token: connection.page_access_token
    )

    if result["error"]
      message = result.dig("error", "message") || "unknown Graph error"
      connection.mark_error!(message) if token_invalid?(result["error"])
      return lead.mark_failed!("Graph fetch failed: #{message}")
    end

    lead.update!(lead_data: result)
    upsert_customer(lead, connection, result)
  rescue StandardError => e
    Rails.logger.error("[MetaLeadAds] processing lead #{lead.id} failed: #{e.message}")
    lead.mark_failed!(e.message)
  end

  def upsert_customer(lead, connection, result)
    fields = lead.field_values
    attrs  = customer_attributes(lead, connection, result, fields)

    existing = find_existing_customer(attrs)
    if existing
      existing.update(repeat_lead: true, created_at: Time.current)
      backfill_meta_ids(existing, attrs)
      return lead.mark_duplicate!(existing)
    end

    customer = Customer.new(attrs)
    unless save_customer(customer)
      return lead.mark_failed!("Customer invalid: #{customer.errors.full_messages.join('; ')}")
    end

    set_whatsapp_chat_id(customer)
    lead.mark_processed!(customer)
  end

  def customer_attributes(lead, connection, result, fields)
    {
      name:            lead_name(fields),
      email:           fields["email"],
      phone:           fields["phone_number"],
      lead_source:     connection.lead_source.presence || "Inbound",
      status:          "Pending",
      notes:           custom_questions_note(fields),
      meta_lead_id:    lead.leadgen_id,
      meta_campaign_id: lead.campaign_id || result["campaign_id"],
      meta_adset_id:   lead.adset_id || result["adset_id"],
      meta_ad_id:      lead.ad_id || result["ad_id"]
    }.compact
  end

  def lead_name(fields)
    full = fields["full_name"].presence
    full ||= [ fields["first_name"], fields["last_name"] ].compact_blank.join(" ").presence
    full || fields["email"].presence || "Facebook Lead"
  end

  # Custom (non-standard) form questions, preserved verbatim in notes so nothing
  # the prospect answered is lost. Full raw data also stays on lead.lead_data.
  def custom_questions_note(fields)
    custom = fields.reject { |k, _| STANDARD_FIELDS.include?(k) }
    return nil if custom.empty?

    lines = custom.map { |q, a| "#{q.to_s.tr('_', ' ').humanize}: #{a}" }
    "Meta Lead Ad answers:\n#{lines.join("\n")}"
  end

  def find_existing_customer(attrs)
    if attrs[:email].present?
      found = Customer.find_by("LOWER(email) = ?", attrs[:email].to_s.downcase.strip)
      return found if found
    end
    if attrs[:phone].present?
      Customer.find_by(phone: normalize_phone(attrs[:phone]))
    end
  end

  def backfill_meta_ids(customer, attrs)
    updates = {}
    %i[meta_lead_id meta_campaign_id meta_adset_id meta_ad_id].each do |k|
      updates[k] = attrs[k] if customer[k].blank? && attrs[k].present?
    end
    customer.update_columns(updates) if updates.any?
  end

  # Tries to save; if the only problem is the phone (Meta sometimes returns a
  # number the strict CRM format rejects), retries without phone and keeps the
  # raw value in notes so the rep can fix it.
  def save_customer(customer)
    return true if customer.save

    if customer.errors[:phone].present?
      raw_phone = customer.phone
      customer.phone = nil
      customer.notes = [ customer.notes, "Unparsed phone from Meta: #{raw_phone}" ].compact_blank.join("\n")
      return customer.save
    end

    false
  end

  def set_whatsapp_chat_id(customer)
    return if customer.phone.blank?
    chat_id = "#{customer.phone.gsub(/\A\+/, '')}@c.us"
    customer.update_columns(whatsapp_chat_id: chat_id) if customer.whatsapp_chat_id.blank?
  end

  def normalize_phone(phone)
    "+" + phone.to_s.gsub(/\D/, "")
  end

  def token_invalid?(error)
    code = error.is_a?(Hash) ? error["code"] : nil
    [ 190, 102, 463, 467 ].include?(code)
  end
end
