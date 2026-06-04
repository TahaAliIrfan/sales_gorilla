class CostEstimate < ApplicationRecord
  belongs_to :user
  belongs_to :customer, optional: true

  # Active Storage attachment for PDF
  has_one_attached :pdf_file

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
  
  private

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
