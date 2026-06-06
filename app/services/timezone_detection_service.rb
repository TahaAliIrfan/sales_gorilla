require 'timezone'

class TimezoneDetectionService
  attr_reader :coordinates, :country_code, :address

  def initialize(coordinates: nil, country_code: nil, address: nil)
    @coordinates = coordinates
    @country_code = country_code
    @address = address
  end

  def detect_timezone
    begin
      timezone_name = nil
      
      # Method 1: Use coordinates for most accurate timezone detection
      if coordinates.present? && coordinates[:lat].present? && coordinates[:lng].present?
        timezone_name = detect_from_coordinates
      end
      
      # Method 2: Fallback to country-based detection
      if timezone_name.nil? && country_code.present?
        timezone_name = detect_from_country_code
      end
      
      # Method 3: Fallback to address-based detection
      if timezone_name.nil? && address.present?
        timezone_name = detect_from_address
      end
      
      # Default fallback
      timezone_name ||= 'UTC'
      
      # Get additional timezone information
      timezone_info = get_timezone_details(timezone_name)
      
      {
        success: true,
        timezone: timezone_name,
        info: timezone_info
      }
    rescue => e
      Rails.logger.error("Timezone detection error: #{e.message}")
      {
        success: false,
        error: e.message,
        timezone: 'UTC',
        info: get_timezone_details('UTC')
      }
    end
  end

  def self.detect_from_phone_number(phone_number)
    service = PhoneLocationService.new(phone_number)
    analysis = service.analyze
    
    if analysis[:success]
      data = analysis[:data]
      
      new(
        coordinates: data[:coordinates],
        country_code: data[:country]
      ).detect_timezone
    else
      { success: false, error: 'Phone number analysis failed', timezone: 'UTC' }
    end
  end

  def self.get_business_hours_for_timezone(timezone_name, country_code = nil)
    # Get business hours based on timezone and cultural norms
    business_hours = calculate_business_hours(timezone_name, country_code)
    
    {
      timezone: timezone_name,
      business_hours: business_hours,
      formatted: format_business_hours(business_hours, timezone_name)
    }
  end

  private

  def detect_from_coordinates
    return nil unless coordinates[:lat].present? && coordinates[:lng].present?
    
    begin
      # Use timezone gem for accurate coordinate-based lookup
      Timezone.configure do |config|
        # You can configure Google API key here if available
        # config.google_api_key = Rails.application.credentials.google_api_key
      end
      
      tz = Timezone.lookup(coordinates[:lat].to_f, coordinates[:lng].to_f)
      return tz.name if tz
    rescue => e
      Rails.logger.warn("Coordinate-based timezone lookup failed: #{e.message}")
    end
    
    nil
  end

  def detect_from_country_code
    return nil unless country_code.present?
    
    # Comprehensive country to primary timezone mapping
    country_timezone_map = {
      # North America
      'US' => 'America/New_York',
      'CA' => 'America/Toronto', 
      'MX' => 'America/Mexico_City',
      
      # Europe
      'GB' => 'Europe/London',
      'IE' => 'Europe/Dublin',
      'FR' => 'Europe/Paris',
      'DE' => 'Europe/Berlin',
      'IT' => 'Europe/Rome',
      'ES' => 'Europe/Madrid',
      'PT' => 'Europe/Lisbon',
      'NL' => 'Europe/Amsterdam',
      'BE' => 'Europe/Brussels',
      'CH' => 'Europe/Zurich',
      'AT' => 'Europe/Vienna',
      'SE' => 'Europe/Stockholm',
      'NO' => 'Europe/Oslo',
      'DK' => 'Europe/Copenhagen',
      'FI' => 'Europe/Helsinki',
      'PL' => 'Europe/Warsaw',
      'CZ' => 'Europe/Prague',
      'HU' => 'Europe/Budapest',
      'GR' => 'Europe/Athens',
      'TR' => 'Europe/Istanbul',
      'RU' => 'Europe/Moscow',
      
      # Asia
      'IN' => 'Asia/Kolkata',
      'PK' => 'Asia/Karachi',
      'BD' => 'Asia/Dhaka',
      'LK' => 'Asia/Colombo',
      'CN' => 'Asia/Shanghai',
      'JP' => 'Asia/Tokyo',
      'KR' => 'Asia/Seoul',
      'TW' => 'Asia/Taipei',
      'HK' => 'Asia/Hong_Kong',
      'SG' => 'Asia/Singapore',
      'MY' => 'Asia/Kuala_Lumpur',
      'TH' => 'Asia/Bangkok',
      'VN' => 'Asia/Ho_Chi_Minh',
      'PH' => 'Asia/Manila',
      'ID' => 'Asia/Jakarta',
      'AF' => 'Asia/Kabul',
      'IR' => 'Asia/Tehran',
      'IQ' => 'Asia/Baghdad',
      'IL' => 'Asia/Jerusalem',
      'JO' => 'Asia/Amman',
      'LB' => 'Asia/Beirut',
      'SY' => 'Asia/Damascus',
      
      # Middle East & Gulf
      'AE' => 'Asia/Dubai',
      'SA' => 'Asia/Riyadh',
      'QA' => 'Asia/Qatar',
      'KW' => 'Asia/Kuwait',
      'BH' => 'Asia/Bahrain',
      'OM' => 'Asia/Muscat',
      'YE' => 'Asia/Aden',
      
      # Africa
      'ZA' => 'Africa/Johannesburg',
      'EG' => 'Africa/Cairo',
      'NG' => 'Africa/Lagos',
      'KE' => 'Africa/Nairobi',
      'ET' => 'Africa/Addis_Ababa',
      'GH' => 'Africa/Accra',
      'MA' => 'Africa/Casablanca',
      'TN' => 'Africa/Tunis',
      'DZ' => 'Africa/Algiers',
      'LY' => 'Africa/Tripoli',
      'SD' => 'Africa/Khartoum',
      
      # Oceania
      'AU' => 'Australia/Sydney',
      'NZ' => 'Pacific/Auckland',
      'FJ' => 'Pacific/Fiji',
      'PG' => 'Pacific/Port_Moresby',
      
      # South America
      'BR' => 'America/Sao_Paulo',
      'AR' => 'America/Argentina/Buenos_Aires',
      'CL' => 'America/Santiago',
      'PE' => 'America/Lima',
      'CO' => 'America/Bogota',
      'VE' => 'America/Caracas',
      'EC' => 'America/Guayaquil',
      'BO' => 'America/La_Paz',
      'PY' => 'America/Asuncion',
      'UY' => 'America/Montevideo',
      'GY' => 'America/Guyana',
      'SR' => 'America/Paramaribo',
      'GF' => 'America/Cayenne',
      
      # Caribbean
      'JM' => 'America/Jamaica',
      'CU' => 'America/Havana',
      'DO' => 'America/Santo_Domingo',
      'PR' => 'America/Puerto_Rico',
      'TT' => 'America/Port_of_Spain',
      'BB' => 'America/Barbados'
    }
    
    country_timezone_map[country_code.upcase]
  end

  def detect_from_address
    # This would implement address-to-timezone conversion
    # For now, return nil as it requires geocoding service
    # In production, you could use Google Maps or similar service
    nil
  end

  def get_timezone_details(timezone_name)
    return {} unless timezone_name.present?
    
    begin
      # Get current time in the timezone
      time_zone = ActiveSupport::TimeZone.find_tzinfo(timezone_name)
      current_period = time_zone.current_period
      current_time = Time.current.in_time_zone(timezone_name)
      
      {
        name: timezone_name,
        abbreviation: current_period.abbreviation,
        offset_hours: current_period.utc_total_offset / 3600.0,
        offset_seconds: current_period.utc_total_offset,
        dst: current_period.dst?,
        current_time: current_time,
        utc_offset: current_time.strftime('%z'),
        formatted_offset: format_utc_offset(current_period.utc_total_offset)
      }
    rescue => e
      Rails.logger.warn("Failed to get timezone details for #{timezone_name}: #{e.message}")
      {
        name: timezone_name,
        abbreviation: nil,
        offset_hours: 0,
        offset_seconds: 0,
        dst: false,
        current_time: Time.current,
        utc_offset: '+0000',
        formatted_offset: 'UTC+0'
      }
    end
  end

  def format_utc_offset(offset_seconds)
    hours = offset_seconds.abs / 3600
    minutes = (offset_seconds.abs % 3600) / 60
    sign = offset_seconds >= 0 ? '+' : '-'
    
    if minutes == 0
      "UTC#{sign}#{hours}"
    else
      "UTC#{sign}#{hours}:#{minutes.to_s.rjust(2, '0')}"
    end
  end

  def self.calculate_business_hours(timezone_name, country_code)
    # Business hours vary by country and culture
    business_patterns = {
      # Western countries - 9 AM to 5 PM
      'US' => { start: 9, end: 17, days: 'Monday to Friday' },
      'CA' => { start: 9, end: 17, days: 'Monday to Friday' },
      'GB' => { start: 9, end: 17, days: 'Monday to Friday' },
      'AU' => { start: 9, end: 17, days: 'Monday to Friday' },
      'NZ' => { start: 9, end: 17, days: 'Monday to Friday' },
      'DE' => { start: 9, end: 17, days: 'Monday to Friday' },
      'FR' => { start: 9, end: 17, days: 'Monday to Friday' },
      'NL' => { start: 9, end: 17, days: 'Monday to Friday' },
      'SE' => { start: 9, end: 17, days: 'Monday to Friday' },
      'NO' => { start: 9, end: 17, days: 'Monday to Friday' },
      'DK' => { start: 9, end: 17, days: 'Monday to Friday' },
      
      # Extended hours - 9 AM to 6 PM
      'IN' => { start: 9, end: 18, days: 'Monday to Friday' },
      'CN' => { start: 9, end: 18, days: 'Monday to Friday' },
      'BR' => { start: 9, end: 18, days: 'Monday to Friday' },
      'RU' => { start: 9, end: 18, days: 'Monday to Friday' },
      'SG' => { start: 9, end: 18, days: 'Monday to Friday' },
      'MY' => { start: 9, end: 18, days: 'Monday to Friday' },
      'TH' => { start: 9, end: 18, days: 'Monday to Friday' },
      'KR' => { start: 9, end: 18, days: 'Monday to Friday' },
      'TW' => { start: 9, end: 18, days: 'Monday to Friday' },
      'HK' => { start: 9, end: 18, days: 'Monday to Friday' },
      
      # South Asia - 10 AM to 6 PM
      'PK' => { start: 10, end: 18, days: 'Monday to Friday' },
      'BD' => { start: 10, end: 18, days: 'Monday to Friday' },
      'LK' => { start: 10, end: 18, days: 'Monday to Friday' },
      
      # Southeast Asia - 8 AM to 6 PM
      'VN' => { start: 8, end: 18, days: 'Monday to Friday' },
      'PH' => { start: 8, end: 18, days: 'Monday to Friday' },
      'ID' => { start: 8, end: 18, days: 'Monday to Friday' },
      'CO' => { start: 8, end: 18, days: 'Monday to Friday' },
      
      # Middle East - 9 AM to 6 PM, Sunday to Thursday
      'AE' => { start: 9, end: 18, days: 'Sunday to Thursday' },
      'SA' => { start: 9, end: 17, days: 'Sunday to Thursday' },
      'QA' => { start: 9, end: 18, days: 'Sunday to Thursday' },
      'KW' => { start: 9, end: 18, days: 'Sunday to Thursday' },
      'BH' => { start: 9, end: 18, days: 'Sunday to Thursday' },
      'OM' => { start: 9, end: 18, days: 'Sunday to Thursday' },
      
      # Africa - 8 AM to 5 PM
      'ZA' => { start: 8, end: 17, days: 'Monday to Friday' },
      'EG' => { start: 9, end: 17, days: 'Monday to Friday' },
      'NG' => { start: 8, end: 17, days: 'Monday to Friday' },
      'KE' => { start: 8, end: 17, days: 'Monday to Friday' },
      
      # Japan - 9 AM to 5 PM
      'JP' => { start: 9, end: 17, days: 'Monday to Friday' },
      
      # Latin America - 9 AM to 6 PM
      'MX' => { start: 9, end: 18, days: 'Monday to Friday' },
      'AR' => { start: 9, end: 18, days: 'Monday to Friday' },
      'CL' => { start: 9, end: 18, days: 'Monday to Friday' },
      'PE' => { start: 9, end: 18, days: 'Monday to Friday' }
    }
    
    # Default pattern if country not found
    default_pattern = { start: 9, end: 17, days: 'Monday to Friday' }
    
    pattern = if country_code.present?
      business_patterns[country_code.upcase] || default_pattern
    else
      default_pattern
    end
    
    pattern
  end

  def self.format_business_hours(business_hours, timezone_name)
    start_hour = business_hours[:start]
    end_hour = business_hours[:end]
    days = business_hours[:days]
    
    # Format hours in 12-hour format
    start_formatted = format_hour(start_hour)
    end_formatted = format_hour(end_hour)
    
    # Get timezone abbreviation
    begin
      time_zone = ActiveSupport::TimeZone.find_tzinfo(timezone_name)
      abbreviation = time_zone.current_period.abbreviation
    rescue
      abbreviation = timezone_name&.split('/')&.last&.tr('_', ' ') || 'UTC'
    end
    
    "#{start_formatted} - #{end_formatted} #{abbreviation} (#{days})"
  end

  def self.format_hour(hour)
    if hour == 0
      '12 AM'
    elsif hour < 12
      "#{hour} AM"
    elsif hour == 12
      '12 PM'
    else
      "#{hour - 12} PM"
    end
  end
end