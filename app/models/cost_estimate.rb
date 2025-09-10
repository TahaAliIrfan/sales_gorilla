class CostEstimate < ApplicationRecord
  belongs_to :user
  
  validates :app_type, presence: true
  validates :description, presence: true, length: { minimum: 10 }
  validates :scale, presence: true, inclusion: { in: %w[mvp moderate enterprise] }
  validates :total_hours, presence: true, numericality: { greater_than: 0 }
  validates :hourly_rate, presence: true, numericality: { greater_than: 0 }
  validates :total_cost, presence: true, numericality: { greater_than: 0 }
  
  before_validation :calculate_total_cost, if: :should_calculate_cost?
  
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
    'mvp' => 'MVP (300-600 hours)',
    'moderate' => 'Moderate Scale (600-1500 hours)',
    'enterprise' => 'Enterprise (1500+ hours)'
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
  
  def app_type_display
    APP_TYPES[app_type] || app_type&.humanize
  end
  
  def scale_display
    SCALES[scale] || scale&.humanize
  end
  
  def formatted_total_cost
    "$#{total_cost.to_f.round(2)}"
  end
  
  private
  
  def should_calculate_cost?
    total_hours.present? && hourly_rate.present? && (total_cost.blank? || total_hours_changed? || hourly_rate_changed?)
  end
  
  def calculate_total_cost
    self.total_cost = total_hours * hourly_rate if total_hours.present? && hourly_rate.present?
  end
end
