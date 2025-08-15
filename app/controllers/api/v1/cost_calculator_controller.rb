module Api
  module V1
    class CostCalculatorController < ApplicationController
      skip_before_action :verify_authenticity_token
      
      # POST /api/v1/cost_calculator
      def cost_calculator
        name = params[:name]
        email = params[:email]
        phone_number = params[:phone_number]
        country = params[:country]
        # to add from CCR
        description = params[:description] || nil
        timezone = params[:timezone] || nil
        preferred_calling_time = params[:preferred_calling_time] || nil
        platform= params[:platform]
        project_scope = params[:project_scope]
        ccr_link = params[:file_url]
        lead_source = 'CCR'

        customer = Customer.find_by(email: email)
        
        if customer.nil?
          # Create a new customer
          customer = Customer.new(
            name: name,
            email: email,
            phone: phone_number,
            country: country,
            lead_source: lead_source,
            status: 'Pending',
            idea_description: description,
            timezone: timezone,
            preferred_calling_time: preferred_calling_time,
            platform: platform,
            project_scope: project_scope,
            ccr_link: ccr_link
          )
        end

        # Handle file upload via multipart form
        if params[:file].present?
          begin
            # Get uploaded file details
            uploaded_file = params[:file]
            
            # Create a descriptive filename with customer name and timestamp
            # Format customer name - remove special characters and replace spaces with underscores
            customer_name = name.present? ? name.gsub(/[^0-9A-Za-z\s]/, '').gsub(/\s+/, '_') : "Unknown"
            timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
            
            # New filename format: CustomerName_CCR_YYYYMMDD_HHMMSS.ext
            new_filename = "#{customer_name}_CCR_#{timestamp}.pdf"
            
            # Attach the uploaded file with the new filename
            customer.file.attach(
              io: uploaded_file.open,
              filename: new_filename,
              content_type: uploaded_file.content_type
            )
            
            Rails.logger.info("File attached successfully: #{new_filename}")
          rescue => e
            Rails.logger.error("File attachment error: #{e.message}")
            # Continue without the file if there's an error
          end
        end
        
        # Save the customer with the attached file

        if customer.save
          response_data = { 
            success: true,
            message: "Successfully added"
          }

          phone_without_plus = customer.phone.gsub(/\A\+/, '')

          # Create WhatsApp chat ID in the required format
          whatsapp_chat_id = "#{phone_without_plus}@c.us"

          # Update the customer record
          customer.update!(whatsapp_chat_id: whatsapp_chat_id)

          
          # Add file info to response if a file was attached
          if params[:file].present? && customer.file.attached?
            response_data[:file] = {
              filename: customer.file.filename.to_s,
              content_type: customer.file.content_type,
              stored: true
            }
          end
          
          return render json: response_data, status: :ok
        else
          return render json: { 
            success: false,
            message: "Failed to save customer",
            errors: customer.errors.full_messages 
          }, status: :unprocessable_entity
        end
      end


      def inbound_lead
        name = params[:name]
        email = params[:email]
        phone_number = params[:phone_number]
        country = params[:country]
        description = params[:description] || nil
        #    timezone = extract_timezone_from_timestamp(params[:timezone])
        preferred_calling_time = params[:preferred_calling_time] || nil
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
