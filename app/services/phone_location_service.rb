require 'phonelib'
require 'timezone'

class PhoneLocationService
  attr_reader :phone_number, :parsed_phone

  def initialize(phone_number)
    @phone_number = phone_number
    @parsed_phone = Phonelib.parse(phone_number)
  end

  def analyze
    return { success: false, error: 'Invalid phone number' } unless valid?

    begin
      location_data = extract_location_data
      timezone_data = extract_timezone_data
      carrier_data = extract_carrier_data

      {
        success: true,
        data: {
          # Basic phone info
          formatted_number: parsed_phone.international,
          national_format: parsed_phone.national,
          country_code: parsed_phone.country_code,
          area_code: parsed_phone.area_code,
          phone_type: parsed_phone.type,
          
          # Geographic data
          country: location_data[:country],
          country_name: location_data[:country_name],
          state: location_data[:state],
          city: location_data[:city],
          region: location_data[:region],
          geo_name: location_data[:geo_name],
          coordinates: location_data[:coordinates],
          
          # Timezone data
          timezone: timezone_data[:timezone],
          timezone_name: timezone_data[:timezone_name],
          timezone_offset: timezone_data[:timezone_offset],
          
          # Carrier data
          carrier: carrier_data[:carrier],
          line_type: carrier_data[:line_type],
          network_operator: carrier_data[:network_operator],
          
          # Additional metadata
          valid: true,
          possible: parsed_phone.possible?,
          analysis_timestamp: Time.current
        }
      }
    rescue => e
      Rails.logger.error("Phone analysis error for #{phone_number}: #{e.message}")
      { success: false, error: e.message }
    end
  end

  def valid?
    parsed_phone.valid?
  end

  def possible?
    parsed_phone.possible?
  end

  private

  def extract_location_data
    country_code = parsed_phone.country
    
    # Get country name from ISO country code
    country_name = get_country_name(country_code)
    
    # Get geographic data from phonelib
    geo_name = nil
    begin
      geo_name = parsed_phone.geo_name if parsed_phone.respond_to?(:geo_name)
    rescue
      # geo_name might not be available for all numbers
    end
    
    # Get detailed location data using area code mapping
    area_code = parsed_phone.area_code
    location_details = get_detailed_location_from_area_code(area_code, country_code)
    
    coordinates = location_details[:coordinates] if location_details

    {
      country: country_code,
      country_name: country_name,
      state: location_details&.dig(:state),
      city: location_details&.dig(:city),
      region: location_details&.dig(:region),
      geo_name: geo_name,
      coordinates: coordinates
    }
  end

  def extract_timezone_data
    # First try to get timezone from phonelib
    phonelib_timezone = nil
    begin
      phonelib_timezone = parsed_phone.timezone if parsed_phone.respond_to?(:timezone)
    rescue
      # timezone might not be available for all numbers
    end
    
    # Get more precise timezone using coordinates if available
    location_data = extract_location_data
    precise_timezone = nil
    
    if location_data[:coordinates]
      lat = location_data[:coordinates][:lat]
      lng = location_data[:coordinates][:lng]
      
      begin
        # Use the timezone gem for precise timezone lookup
        tz_lookup = Timezone.lookup(lat, lng)
        precise_timezone = tz_lookup.name if tz_lookup
      rescue => e
        Rails.logger.warn("Timezone lookup failed for coordinates #{lat}, #{lng}: #{e.message}")
      end
    end
    
    # Use the most precise timezone available
    final_timezone = precise_timezone || phonelib_timezone || get_default_timezone_for_country(parsed_phone.country)
    
    # Calculate timezone offset and preferred calling times
    timezone_info = get_timezone_info(final_timezone)
    
    {
      timezone: final_timezone,
      timezone_name: timezone_info[:name],
      timezone_offset: timezone_info[:offset],
      timezone_abbreviation: timezone_info[:abbreviation],
      dst_active: timezone_info[:dst],
      preferred_calling_time: calculate_preferred_calling_time(final_timezone, parsed_phone.country)
    }
  end

  def extract_carrier_data
    carrier = nil
    line_type = nil
    
    begin
      carrier = parsed_phone.carrier if parsed_phone.respond_to?(:carrier)
    rescue
      # carrier might not be available for all numbers
    end
    
    begin
      line_type = parsed_phone.type.to_s if parsed_phone.respond_to?(:type)
    rescue
      # type might not be available for all numbers
    end
    
    {
      carrier: carrier,
      line_type: line_type,
      network_operator: carrier # For now, use carrier as network operator
    }
  end

  def get_detailed_location_from_area_code(area_code, country_code)
    return nil unless area_code.present? && country_code.present?
    
    # Use the comprehensive area code service for all countries
    ComprehensiveAreaCodeService.get_location_data(area_code, country_code)
  end

  def get_default_timezone_for_country(country_code)
    # Comprehensive country to timezone mapping
    timezone_map = {
      'US' => 'America/New_York',      # Default to Eastern Time
      'CA' => 'America/Toronto',       # Default to Eastern Time
      'GB' => 'Europe/London',
      'AU' => 'Australia/Sydney',
      'DE' => 'Europe/Berlin',
      'FR' => 'Europe/Paris',
      'IN' => 'Asia/Kolkata',
      'PK' => 'Asia/Karachi',
      'JP' => 'Asia/Tokyo',
      'CN' => 'Asia/Shanghai',
      'BR' => 'America/Sao_Paulo',
      'RU' => 'Europe/Moscow',
      'ZA' => 'Africa/Johannesburg',
      'EG' => 'Africa/Cairo',
      'AE' => 'Asia/Dubai',
      'SA' => 'Asia/Riyadh',
      'SG' => 'Asia/Singapore',
      'MY' => 'Asia/Kuala_Lumpur',
      'TH' => 'Asia/Bangkok',
      'VN' => 'Asia/Ho_Chi_Minh',
      'PH' => 'Asia/Manila',
      'ID' => 'Asia/Jakarta',
      'KR' => 'Asia/Seoul',
      'TW' => 'Asia/Taipei',
      'HK' => 'Asia/Hong_Kong',
      'NZ' => 'Pacific/Auckland',
      'MX' => 'America/Mexico_City',
      'AR' => 'America/Argentina/Buenos_Aires',
      'CL' => 'America/Santiago',
      'CO' => 'America/Bogota',
      'PE' => 'America/Lima',
      'VE' => 'America/Caracas'
    }

    timezone_map[country_code.upcase] || 'UTC'
  end

  def get_timezone_info(timezone_name)
    return { name: nil, offset: nil } unless timezone_name.present?

    begin
      tz = ActiveSupport::TimeZone.find_tzinfo(timezone_name)
      current_time = Time.current
      
      {
        name: timezone_name,
        offset: tz.current_period.utc_total_offset / 3600.0, # Convert to hours
        abbreviation: tz.current_period.abbreviation
      }
    rescue => e
      Rails.logger.warn("Failed to get timezone info for #{timezone_name}: #{e.message}")
      { name: timezone_name, offset: nil, abbreviation: nil }
    end
  end

  def calculate_preferred_calling_time(timezone_name, country_code)
    # Business hours vary by country and culture
    business_hours_map = {
      'US' => '9 AM - 5 PM',
      'CA' => '9 AM - 5 PM',
      'GB' => '9 AM - 5 PM',
      'AU' => '9 AM - 5 PM',
      'DE' => '9 AM - 5 PM',
      'FR' => '9 AM - 5 PM',
      'IN' => '9 AM - 6 PM',
      'PK' => '10 AM - 6 PM',
      'JP' => '9 AM - 5 PM',
      'CN' => '9 AM - 6 PM',
      'BR' => '9 AM - 6 PM',
      'RU' => '9 AM - 6 PM',
      'AE' => '9 AM - 6 PM',
      'SA' => '9 AM - 5 PM',
      'SG' => '9 AM - 6 PM',
      'MY' => '9 AM - 6 PM',
      'TH' => '9 AM - 6 PM',
      'VN' => '8 AM - 6 PM',
      'PH' => '8 AM - 6 PM',
      'ID' => '8 AM - 6 PM',
      'KR' => '9 AM - 6 PM',
      'TW' => '9 AM - 6 PM',
      'HK' => '9 AM - 6 PM',
      'NZ' => '9 AM - 5 PM',
      'MX' => '9 AM - 6 PM',
      'AR' => '9 AM - 6 PM',
      'CL' => '9 AM - 6 PM',
      'CO' => '8 AM - 6 PM',
      'ZA' => '8 AM - 5 PM',
      'EG' => '9 AM - 5 PM'
    }

    hours = business_hours_map[country_code.upcase] || '9 AM - 5 PM'
    
    # Get timezone abbreviation for the calling time
    timezone_info = get_timezone_info(timezone_name)
    abbreviation = timezone_info[:abbreviation] || timezone_name&.split('/')&.last&.tr('_', ' ')
    
    "#{hours} #{abbreviation} (Monday to Friday)"
  end
  
  def get_country_name(country_code)
    # Map common country codes to full country names
    country_names = {
      'US' => 'United States',
      'CA' => 'Canada',
      'GB' => 'United Kingdom',
      'AU' => 'Australia',
      'DE' => 'Germany',
      'FR' => 'France',
      'IT' => 'Italy',
      'ES' => 'Spain',
      'IN' => 'India',
      'PK' => 'Pakistan',
      'CN' => 'China',
      'JP' => 'Japan',
      'KR' => 'South Korea',
      'BR' => 'Brazil',
      'MX' => 'Mexico',
      'AR' => 'Argentina',
      'RU' => 'Russia',
      'AE' => 'United Arab Emirates',
      'SA' => 'Saudi Arabia',
      'EG' => 'Egypt',
      'ZA' => 'South Africa',
      'NG' => 'Nigeria',
      'SG' => 'Singapore',
      'MY' => 'Malaysia',
      'TH' => 'Thailand',
      'VN' => 'Vietnam',
      'PH' => 'Philippines',
      'ID' => 'Indonesia',
      'TR' => 'Turkey',
      'IL' => 'Israel',
      'NZ' => 'New Zealand',
      'NL' => 'Netherlands',
      'BE' => 'Belgium',
      'CH' => 'Switzerland',
      'AT' => 'Austria',
      'SE' => 'Sweden',
      'NO' => 'Norway',
      'DK' => 'Denmark',
      'FI' => 'Finland',
      'IE' => 'Ireland',
      'PT' => 'Portugal',
      'GR' => 'Greece',
      'PL' => 'Poland',
      'CZ' => 'Czech Republic',
      'HU' => 'Hungary',
      'RO' => 'Romania',
      'BG' => 'Bulgaria',
      'HR' => 'Croatia',
      'SK' => 'Slovakia',
      'SI' => 'Slovenia',
      'QA' => 'Qatar',
      'KW' => 'Kuwait',
      'BH' => 'Bahrain',
      'OM' => 'Oman',
      'JO' => 'Jordan',
      'LB' => 'Lebanon',
      'IQ' => 'Iraq',
      'YE' => 'Yemen',
      'SY' => 'Syria',
      'AF' => 'Afghanistan'
    }
    
    country_names[country_code.to_s.upcase] || country_code.to_s.upcase
  end
end