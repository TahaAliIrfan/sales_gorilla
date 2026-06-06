class CustomerLocation < ApplicationRecord
  belongs_to :customer

  validates :customer_id, uniqueness: true
  validates :analysis_version, presence: true
  validates :analyzed_at, presence: true
  
  # Scopes
  scope :analyzed_after, ->(date) { where('analyzed_at > ?', date) }
  scope :by_country, ->(country) { where(country_iso: country.upcase) }
  scope :by_timezone, ->(timezone) { where(timezone: timezone) }
  scope :high_confidence, -> { where('location_confidence >= ? AND timezone_confidence >= ?', 70, 70) }
  scope :recent_analysis, -> { where('analyzed_at > ?', 30.days.ago) }

  # Class methods
  def self.create_from_analysis(customer, analysis_data)
    return nil unless analysis_data[:success]
    
    data = analysis_data[:data]
    
    location_attrs = {
      customer: customer,
      
      # Basic phone info
      formatted_number: data[:formatted_number],
      national_format: data[:national_format],
      country_code: data[:country_code],
      area_code: data[:area_code],
      phone_type: data[:phone_type],
      
      # Geographic data
      country_iso: data[:country],
      country_name: data[:country_name],
      state_province: data[:state],
      city: data[:city],
      region: data[:region],
      geo_name: data[:geo_name],
      
      # Coordinates
      latitude: data[:coordinates]&.dig(:lat),
      longitude: data[:coordinates]&.dig(:lng),
      
      # Timezone data
      timezone: data[:timezone],
      timezone_abbreviation: data[:timezone_abbreviation],
      timezone_offset: data[:timezone_offset],
      dst_active: data[:dst_active],
      
      # Carrier data
      carrier: data[:carrier],
      line_type: data[:line_type],
      network_operator: data[:network_operator],
      
      # Analysis metadata
      analysis_version: '2.0',
      analyzed_at: Time.current,
      data_source: determine_data_source(data),
      raw_analysis_data: analysis_data,
      location_confidence: calculate_location_confidence(data),
      timezone_confidence: calculate_timezone_confidence(data)
    }
    
    # Use upsert to handle existing records
    where(customer: customer).first_or_initialize.tap do |location|
      location.update!(location_attrs)
    end
  end

  # Instance methods
  def current_time
    return Time.current unless timezone.present?
    
    begin
      Time.current.in_time_zone(timezone)
    rescue => e
      Rails.logger.warn("Invalid timezone #{timezone} for customer location #{id}: #{e.message}")
      Time.current
    end
  end


  def location_summary
    parts = [city, state_province, country_name].compact.reject(&:blank?)
    parts.any? ? parts.join(', ') : country_name || country_iso
  end

  def coordinates_available?
    latitude.present? && longitude.present?
  end

  def high_confidence?
    location_confidence >= 70 && timezone_confidence >= 70
  end

  private

  def self.determine_data_source(data)
    sources = []
    sources << 'phonelib' if data[:formatted_number].present?
    sources << 'area_code_db' if data[:coordinates].present?
    sources << 'coordinates' if data[:timezone].present? && data[:coordinates].present?
    sources.join(', ')
  end

  def self.calculate_location_confidence(data)
    confidence = 0
    
    # Base confidence from phone number validity
    confidence += 30 if data[:formatted_number].present?
    
    # Country identification
    confidence += 20 if data[:country].present?
    
    # Geographic specificity
    confidence += 15 if data[:state].present?
    confidence += 15 if data[:city].present?
    confidence += 10 if data[:area_code].present?
    confidence += 10 if data[:coordinates].present?
    
    [confidence, 100].min
  end

  def self.calculate_timezone_confidence(data)
    confidence = 0
    
    # Base timezone presence
    confidence += 40 if data[:timezone].present?
    
    # Precision indicators
    confidence += 30 if data[:coordinates].present? # Coordinate-based is most accurate
    confidence += 20 if data[:timezone_offset].present?
    confidence += 10 if data[:preferred_calling_time].present?
    
    [confidence, 100].min
  end
end
