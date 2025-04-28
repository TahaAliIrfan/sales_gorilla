class WhatsappMessageAnalysisWorker
  include Sidekiq::Worker
  
  sidekiq_options retry: 3, queue: 'whatsapp_analysis'
  
  def perform(chat_id, message_body)
    # Return early if chat_id is missing
    return unless chat_id.present?
    
    # Extract the phone number from the chat_id
    phone_number = extract_phone_number(chat_id)
    
    # Create the DeepSeek analysis service
    analysis_service = DeepSeekCustomerAnalysisService.new
    
    # Get customer info from DeepSeek
    customer_info = analysis_service.analyze_customer_message(chat_id, message_body, phone_number)
    
    # Return early if analysis failed
    return unless customer_info.present?
    
    # Create or update the customer with the analyzed information
    customer = create_or_update_customer(chat_id, customer_info)
    
    # If timezone or preferred calling time is still not set, try to analyze the phone number specifically
    if customer.present? && (customer.timezone.blank? || customer.preferred_calling_time.blank? || customer.preferred_calling_time == 'Not Applicable')
      # If these fields aren't present in the first analysis, try to analyze the phone specifically
      if customer_info[:timezone] == 'N/A' || customer_info[:preferred_calling_time] == 'N/A'
        timezone_info = analysis_service.analyze_phone_for_timezone(phone_number)
        
        if timezone_info.present?
          # Update only timezone and preferred calling time
          customer.update(
            timezone: timezone_info[:timezone] == 'N/A' ? customer.timezone : timezone_info[:timezone],
            preferred_calling_time: timezone_info[:preferred_calling_time] == 'N/A' ? customer.preferred_calling_time : timezone_info[:preferred_calling_time]
          )
          
          # Record this activity
          customer.customer_activities.create!(
            user_id: customer.user_id,
            activity_type: 'phone_analysis',
            description: "Phone analysis for timezone: Timezone - #{timezone_info[:timezone]}, Preferred calling time - #{timezone_info[:preferred_calling_time]}"
          )
          
          Rails.logger.info("Updated timezone info for customer from WhatsApp chat_id #{chat_id}")
        end
      end
    end
  end
  
  private
  
  def extract_phone_number(chat_id)
    # WhatsApp chat IDs are formatted as: "1234567890@c.us"
    # Remove the "@c.us" suffix to get the phone number
    chat_id.gsub(/@c\.us$/, '')
  end
  
  def create_or_update_customer(chat_id, customer_info)
    # Find existing customer or create a new one
    customer = Customer.find_or_initialize_by(whatsapp_chat_id: chat_id)
    
    # Update customer attributes with analyzed information
    customer.name = customer_info[:name] unless customer_info[:name] == 'N/A' || customer.name.present? && customer.name != 'Whatsapp lead'
    customer.email = customer_info[:email] unless customer_info[:email] == 'N/A' || customer.email.present?
    customer.phone = "+#{extract_phone_number(chat_id)}" unless customer.phone.present?
    customer.country = customer_info[:country] unless customer_info[:country] == 'N/A' || customer.country.present?
    customer.preferred_calling_time = customer_info[:preferred_calling_time] unless customer_info[:preferred_calling_time] == 'N/A' || customer.preferred_calling_time.present?
    customer.idea_description = customer_info[:idea_description] unless customer_info[:idea_description] == 'N/A' || customer.idea_description.present?
    customer.timezone = customer_info[:timezone] unless customer_info[:timezone] == 'N/A' || customer.timezone.present?
    customer.lead_source = 'WA' unless customer.lead_source.present?
    
    # Save the customer
    if customer.save
      Rails.logger.info("Customer information updated from WhatsApp message analysis: #{customer.id}")
      customer
    else
      Rails.logger.error("Failed to save customer from WhatsApp analysis: #{customer.errors.full_messages.join(', ')}")
      nil
    end
  end
end 