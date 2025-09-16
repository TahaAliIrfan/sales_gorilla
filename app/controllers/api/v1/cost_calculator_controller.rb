module Api
  module V1
    class CostCalculatorController < ApplicationController
      skip_before_action :verify_authenticity_token

      def inbound_lead
        name = params[:name]
        email = params[:email]
        phone_number = params[:phone_number]
        country = params[:country]
        description = params[:description] || nil
        preferred_calling_time = parse_preferred_time(params[:preferred_time])
        lead_source = params[:lead_source] || 'Inbound'

        customer = Customer.find_by(email: email)

        if customer.nil?
          customer = Customer.new(
            name: name,
            email: email,
            phone: phone_number,
            country: country,
            lead_source: lead_source,
            status: 'Pending',
            idea_description: description,
            preferred_calling_time: preferred_calling_time,
            meta_lead_id: params[:meta_lead_id],
            facebook_click_id: params[:facebook_click_id],
            browser_id: params[:browser_id],
            meta_campaign_id: params[:meta_campaign_id],
            meta_adset_id: params[:meta_adset_id],
            meta_ad_id: params[:meta_ad_id]
          )
        else
          customer.update!(created_at: Time.current, repeat_lead: true)
        end

        if customer.save

          if customer.phone.present?
            phone_without_plus = customer.phone.gsub(/\A\+/, '')
            whatsapp_chat_id = "#{phone_without_plus}@c.us"
            customer.update!(whatsapp_chat_id: whatsapp_chat_id)
          end


          return render json: { success: true, message: "Successfully added" }, status: :ok
        end
      end
      
      private
      
      def normalize_phone(phone)
        # Strip any whitespace
        cleaned_phone = phone.strip
        
        # Check if the phone already has a plus sign
        has_plus = cleaned_phone.start_with?('+')
        
        # Remove all non-digit characters
        digits_only = cleaned_phone.gsub(/\D/, '')
        
        # Add the plus sign back if it was there, or add it if it wasn't
        '+' + digits_only
      end

      def parse_preferred_time(timestamp)
        return nil if timestamp.blank?
        
        begin
          # Parse ISO 8601 timestamp format like "2025-08-26T07:00:00+0200"
          parsed_time = Time.parse(timestamp)
          
          # Format as readable time with timezone
          # Example: "7:00 AM (+02:00)"
          formatted_time = parsed_time.strftime("%I:%M %p")
          timezone_offset = parsed_time.strftime("%z")
          formatted_offset = "#{timezone_offset[0]}#{timezone_offset[1..2]}:#{timezone_offset[3..4]}"
          
          return "#{formatted_time} (#{formatted_offset})"
        rescue => e
          Rails.logger.warn("Failed to parse preferred_time '#{timestamp}': #{e.message}")
          # Return the original value if parsing fails
          return timestamp
        end
      end

      def extract_timezone_from_timestamp(timestamp)
        return nil if timestamp.blank?
        
        begin
          # Extract timezone offset from formats like "2024-09-24T10:52:24+0000"
          # The timezone is the part after the time ("+0000" in this example)
          if timestamp =~ /.*T\d{2}:\d{2}:\d{2}([+-]\d{4})/
            offset = $1
            # Format as "+00:00" style for better readability
            formatted_offset = "#{offset[0]}#{offset[1..2]}:#{offset[3..4]}"
            return formatted_offset
          end
          return nil
        rescue
          return nil
        end
      end
    end
  end
end
