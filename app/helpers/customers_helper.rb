module CustomersHelper
  def customer_status_border_class(customer)
    case customer.status
    when 'Pending' then 'border-l-4 border-yellow-400'
    when 'Contact Established' then 'border-l-4 border-green-400'
    when 'Contact Not Established' then 'border-l-4 border-red-400'
    when 'Unresponsive' then 'border-l-4 border-orange-400'
    when 'Converted' then 'border-l-4 border-blue-400'
    when 'Proposal Sent' then 'border-l-4 border-indigo-400'
    when 'Not Interested' then 'border-l-4 border-gray-400'
    when 'Exhausted' then 'border-l-4 border-purple-400'
    when 'Invalid' then 'border-l-4 border-purple-400'
    when 'Retarget' then 'border-l-4 border-amber-400'
    when 'Exhausted_1' then 'border-l-4 border-pink-400'
    else 'border-l-4 border-gray-200'
    end
  end
  
  def customer_status_color_class(status)
    case status
    when 'Pending' then 'bg-yellow-100 text-yellow-800'
    when 'Contact Established' then 'bg-green-100 text-green-800'
    when 'Contact Not Established' then 'bg-red-100 text-red-800'
    when 'Unresponsive' then 'bg-orange-100 text-orange-800'
    when 'Converted' then 'bg-blue-100 text-blue-800'
    when 'Proposal Sent' then 'bg-indigo-100 text-indigo-800'
    when 'Not Interested' then 'bg-gray-100 text-gray-800'
    when 'Exhausted' then 'bg-purple-100 text-purple-800'
    when 'Invalid' then 'bg-purple-100 text-purple-800'
    when 'Retarget' then 'bg-amber-100 text-amber-800'
    when 'Exhausted_1' then 'bg-pink-100 text-pink-800'
    else 'bg-gray-100 text-gray-800'
    end
  end

  def display_preferred_calling_time(preferred_calling_time)
    return 'Not Specified' if preferred_calling_time.blank? || preferred_calling_time == 'Not Applicable'
    
    # Check if it's already formatted by our API (contains parentheses with timezone)
    if preferred_calling_time.match(/\d{1,2}:\d{2}\s+(AM|PM)\s+\([+-]\d{2}:\d{2}\)/)
      return preferred_calling_time
    end
    
    # Check if it looks like an ISO 8601 timestamp and try to parse it
    if preferred_calling_time.match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{4}/)
      begin
        parsed_time = Time.parse(preferred_calling_time)
        formatted_time = parsed_time.strftime("%I:%M %p")
        timezone_offset = parsed_time.strftime("%z")
        formatted_offset = "#{timezone_offset[0]}#{timezone_offset[1..2]}:#{timezone_offset[3..4]}"
        return "#{formatted_time} (#{formatted_offset})"
      rescue => e
        Rails.logger.warn("Failed to parse preferred calling time '#{preferred_calling_time}': #{e.message}")
        # Fall through to return original value
      end
    end
    
    # Return the original value for any other format (text descriptions, etc.)
    preferred_calling_time
  end
  
  def format_preferred_calling_time(time_str, current_customer_time)
    return time_str unless time_str.present? && current_customer_time
    
    # Highlight the current day if it's mentioned in the time string
    current_day = current_customer_time.strftime("%A")
    current_day_short = current_customer_time.strftime("%a")
    
    days_of_week = %w[Monday Tuesday Wednesday Thursday Friday Saturday Sunday]
    days_short = %w[Mon Tue Wed Thu Fri Sat Sun]
    
    highlighted_time = time_str.dup
    
    # Check for day mentions and highlight the current day
    days_of_week.each_with_index do |day, i|
      if highlighted_time.include?(day)
        if day == current_day
          highlighted_time.gsub!(day, "<span class='text-green-600 font-semibold'>#{day}</span>")
        end
      end
      
      if highlighted_time.include?(days_short[i])
        if days_short[i] == current_day_short
          highlighted_time.gsub!(days_short[i], "<span class='text-green-600 font-semibold'>#{days_short[i]}</span>")
        end
      end
    end
    
    # Check for "weekday" or "weekend" and highlight if appropriate
    if highlighted_time.include?("weekday") && !current_customer_time.saturday? && !current_customer_time.sunday?
      highlighted_time.gsub!("weekday", "<span class='text-green-600 font-semibold'>weekday</span>")
    end
    
    if highlighted_time.include?("weekend") && (current_customer_time.saturday? || current_customer_time.sunday?)
      highlighted_time.gsub!("weekend", "<span class='text-green-600 font-semibold'>weekend</span>")
    end
    
    # Extract time parts
    current_hour = current_customer_time.hour
    current_ampm = current_customer_time.strftime("%p") # AM or PM
    
    # Highlight time if in range
    time_regex = /(\d{1,2})\s*([AaPp][Mm])(?:\s*[-–—]\s*)(\d{1,2})\s*([AaPp][Mm])/
    if time_regex.match(highlighted_time)
      start_hour = $1.to_i
      start_ampm = $2.upcase
      end_hour = $3.to_i
      end_ampm = $4.upcase
      
      # Convert to 24-hour for comparison
      start_hour_24 = start_hour % 12
      start_hour_24 += 12 if start_ampm == "PM"
      
      end_hour_24 = end_hour % 12
      end_hour_24 += 12 if end_ampm == "PM"
      
      # Check if current hour is in range
      is_in_range = false
      if start_hour_24 <= end_hour_24
        is_in_range = current_hour >= start_hour_24 && current_hour <= end_hour_24
      else
        is_in_range = current_hour >= start_hour_24 || current_hour <= end_hour_24
      end
      
      if is_in_range
        highlighted_time.gsub!(time_regex, 
          "<span class='text-green-600 font-semibold'>\\1 \\2</span> - <span class='text-green-600 font-semibold'>\\3 \\4</span>"
        )
      end
    end
    
    highlighted_time.html_safe
  end
  
  def next_available_calling_time(customer)
    return nil unless customer.preferred_calling_time.present? && 
                     customer.preferred_calling_time != 'Not Applicable' && 
                     !customer.is_preferred_calling_time? &&
                     customer.current_time_in_timezone
                     
    current_time = customer.current_time_in_timezone
    time_str = customer.preferred_calling_time
    
    # Extract time ranges
    time_regex = /(\d{1,2})\s*([AaPp][Mm])(?:\s*[-–—]\s*)(\d{1,2})\s*([AaPp][Mm])/
    if time_regex.match(time_str)
      start_hour = $1.to_i
      start_ampm = $2.upcase
      end_hour = $3.to_i
      end_ampm = $4.upcase
      
      # Convert to 24-hour for comparison
      start_hour_24 = start_hour % 12
      start_hour_24 += 12 if start_ampm == "PM"
      
      current_hour = current_time.hour
      
      # Check for day constraints
      day_constraints = []
      if time_str =~ /\(([^)]+)\)/
        day_part = $1.downcase
        # Check for common day patterns
        if day_part.include?("weekday") || day_part.include?("week day")
          day_constraints = %w[monday tuesday wednesday thursday friday]
        elsif day_part.include?("weekend")
          day_constraints = %w[saturday sunday]
        elsif day_part.include?("monday to friday") || day_part.include?("mon to fri")
          day_constraints = %w[monday tuesday wednesday thursday friday]
        else
          # Check for individual days mentioned
          %w[monday tuesday wednesday thursday friday saturday sunday].each do |day|
            day_constraints << day if day_part.include?(day)
          end
        end
      end
      
      current_day = current_time.strftime("%A").downcase
      
      # If today is in the constraints but current time is past the window, next time is tomorrow
      if day_constraints.include?(current_day) && current_hour > start_hour_24
        return "Tomorrow at #{start_hour} #{start_ampm}"
      end
      
      # If today is in the constraints and current time is before the window, next time is today
      if day_constraints.include?(current_day) && current_hour < start_hour_24
        hours_until = start_hour_24 - current_hour
        return "Today in #{hours_until} hour#{'s' if hours_until != 1} at #{start_hour} #{start_ampm}"
      end
      
      # If today is not in the constraints, find the next day that is
      if day_constraints.any? && !day_constraints.include?(current_day)
        all_days = %w[monday tuesday wednesday thursday friday saturday sunday]
        current_day_index = all_days.index(current_day)
        
        # Find the next day in the constraints
        days_until_next = nil
        (1..7).each do |i|
          next_day_index = (current_day_index + i) % 7
          next_day = all_days[next_day_index]
          if day_constraints.include?(next_day)
            days_until_next = i
            break
          end
        end
        
        if days_until_next
          next_day_name = days_until_next == 1 ? "Tomorrow" : "In #{days_until_next} days"
          return "#{next_day_name} at #{start_hour} #{start_ampm}"
        end
      end
    end
    
    # If no specific time could be determined
    nil
  end
end
