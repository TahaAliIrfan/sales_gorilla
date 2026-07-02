class CostEstimate < ApplicationRecord
  belongs_to :user
  belongs_to :customer, optional: true

  # Active Storage attachment for PDF
  has_one_attached :pdf_file

  # AI-generated concept screens embedded in the proposal PDF
  has_many_attached :mockup_images

  # Status constants
  STATUSES = {
    init: 'init',
    final: 'final'
  }.freeze

  validates :app_type, presence: true, unless: -> { application_types.present? }
  validates :description, presence: true, length: { minimum: 10 }
  validates :scale, presence: true, inclusion: { in: %w[mvp moderate enterprise mid small] }
  validates :total_hours, presence: true, numericality: { greater_than: 0 }
  validates :hourly_rate, presence: true, numericality: { greater_than: 0 }
  validates :total_cost, presence: true, numericality: { greater_than: 0 }
  validates :status, inclusion: { in: STATUSES.values }, allow_nil: false

  # Customer validation: either customer_id or customer_name must be present
  validates :customer_name, presence: true, unless: :customer_id?
  validates :customer_id, presence: true, unless: :customer_name?

  before_validation :calculate_total_cost, if: :should_calculate_cost?
  before_validation :set_default_status, if: :new_record?
  
  APP_TYPES = {
    'web' => 'Web Application',
    'mobile_ios' => 'Mobile Application (iOS)',
    'mobile_android' => 'Mobile Application (Android)',
    'mobile_cross' => 'Mobile Application (Cross-platform)',
    'desktop' => 'Desktop Application',
    'ecommerce' => 'E-commerce Platform',
    'crm' => 'CRM System',
    'api' => 'API/Backend Service',
    'custom' => 'Custom Software'
  }.freeze
  
  SCALES = {
    'mvp' => 'MVP',
    'moderate' => 'Moderate Scale',
    'enterprise' => 'Enterprise'
  }.freeze
  
  def features
    return [] if features_json.blank?
    
    begin
      JSON.parse(features_json)
    rescue JSON::ParserError
      []
    end
  end
  
  def features=(features_array)
    self.features_json = features_array.to_json
  end

  def application_types_array
    return [] if application_types.blank?

    begin
      JSON.parse(application_types)
    rescue JSON::ParserError
      []
    end
  end

  def application_types_array=(types_array)
    self.application_types = types_array.to_json
  end

  def proposed_features_array
    return [] if proposed_features.blank?

    begin
      JSON.parse(proposed_features)
    rescue JSON::ParserError
      []
    end
  end

  def proposed_features_array=(features_array)
    self.proposed_features = features_array.to_json
  end

  def init_status?
    status == STATUSES[:init]
  end

  def final_status?
    status == STATUSES[:final]
  end

  def app_type_display
    APP_TYPES[app_type] || app_type&.humanize
  end
  
  def scale_display
    SCALES[scale] || scale&.humanize
  end
  
  def formatted_total_cost
    "$#{total_cost.to_f.round(2)}"
  end
  
  def customer_display_name
    customer&.name || customer_name || "Unknown Customer"
  end
  
  def customer_phone
    customer&.phone_number || ""
  end
  
  def customer_email
    customer&.email || ""
  end

  # ── Parsed AI-generated JSON columns (safe against malformed payloads) ──

  def executive_summary_data
    safe_parse_hash(executive_summary)
  end

  def similar_apps_data
    parsed = safe_parse(similar_apps)
    parsed.is_a?(Array) ? parsed : []
  end

  def feature_prioritization_data
    safe_parse_hash(feature_prioritization)
  end

  def technical_info_data
    safe_parse_hash(technical_information_summary)
  end

  def market_research_data
    safe_parse_hash(market_research)
  end

  # ── Platform detection (drives store fees & operational cost lines) ──

  def platforms
    types = application_types_array.map { |t| t.to_s.downcase }
    types << app_type.to_s.downcase if types.empty? && app_type.present?
    types
  end

  def mobile_app?
    platforms.any? { |t| t.match?(/mobile|ios|android|cross/) }
  end

  def web_app?
    platforms.any? { |t| t.match?(/web|ecommerce|e-commerce|crm|saas|portal|desktop|api/) }
  end

  def requires_ios_store?
    platforms.any? { |t| t.match?(/ios|cross/) } || generic_mobile?
  end

  def requires_android_store?
    platforms.any? { |t| t.match?(/android|cross/) } || generic_mobile?
  end

  # Generates and persists the AI proposal narrative (proposed product name,
  # similar apps, executive summary, feature prioritization) if not already
  # present. Called from both the email job and the dashboard PDF download so
  # every proposal carries a proposed name.
  def ensure_proposal_content!
    # Regenerate when market_research is missing too, so estimates created
    # before that section existed pick it up on the next send/download.
    return if app_name.present? && market_research.present?

    analysis = CostEstimateAiService.new.generate_project_analysis(self)
    if analysis
      update!(
        app_name: analysis['app_name'],
        similar_apps: analysis['similar_apps'].to_json,
        technical_information_summary: analysis['technical_info'].to_json,
        executive_summary: analysis['executive_summary'].to_json,
        feature_prioritization: analysis['feature_prioritization'].to_json,
        market_research: analysis['market_research'].to_json
      )
    else
      # Don't clobber previously generated content on a transient API failure
      update!(app_name: "#{customer_display_name}'s App", similar_apps: [].to_json) if app_name.blank?
      Rails.logger.warn("CostEstimate##{id}: AI analysis failed, keeping existing/fallback content")
    end
  end

  # Combined feature text used to infer usage-based services (payments, maps, SMS)
  def feature_text
    names = features.map { |f| [f['name'], f['description']].compact.join(' ') }
    names += proposed_features_array.map(&:to_s)
    ([description] + names).join(' ').downcase
  end

  private

  # Only "mobile" was selected with no explicit OS — assume both stores
  def generic_mobile?
    platforms.any? { |t| t.match?(/mobile/) } && platforms.none? { |t| t.match?(/ios|android/) }
  end

  def safe_parse(raw)
    return nil if raw.blank?
    JSON.parse(raw)
  rescue JSON::ParserError
    nil
  end

  def safe_parse_hash(raw)
    parsed = safe_parse(raw)
    parsed.is_a?(Hash) ? parsed : {}
  end

  def set_default_status
    self.status ||= STATUSES[:init]
  end

  def should_calculate_cost?
    total_hours.present? && hourly_rate.present? && (total_cost.blank? || total_hours_changed? || hourly_rate_changed?)
  end

  def calculate_total_cost
    self.total_cost = total_hours * hourly_rate if total_hours.present? && hourly_rate.present?
  end
end
