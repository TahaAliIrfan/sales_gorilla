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
        file_data = params[:file]
        # to add from CCR
        description = params[:description] || nil
        timezone = params[:timezone] || nil
        preferred_calling_time = params[:preferred_calling_time] || nil
        platform= params[:platform]
        project_scope = params[:project_scope]
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
            project_scope: project_scope
          )
        end

        if file_data.present?
          begin
            # Decode base64 data
            content_type, encoded_file = file_data.match(/data:(.*);base64,(.*)/).captures
            decoded_file = Base64.decode64(encoded_file)
            
            # Determine file extension based on content type
            extension = case content_type
                        when 'application/pdf'
                          '.pdf'
                        when 'application/msword'
                          '.doc'
                        when 'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
                          '.docx'
                        when /^image\/(jpeg|jpg|png|gif)$/
                          ".#{content_type.split('/').last}"
                        else
                          '.bin' # Default binary extension
                        end
            
            # Create a temporary file
            temp_file = Tempfile.new(['attachment', extension])
            temp_file.binmode
            temp_file.write(decoded_file)
            temp_file.rewind
            
            # Attach the file directly to the customer
            customer.file.attach(
              io: temp_file,
              filename: "cost_calculator_attachment#{extension}",
              content_type: content_type
            )
          rescue => e
            Rails.logger.error("File attachment error: #{e.message}")
            # Continue without the file if there's an error
          end
        end
        
        # Save the customer with the attached file
        if customer.save
          return render json: { 
            success: true,
          message: "Successfully added"
          }, status: :ok
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
        lead_source = params[:lead_source]

        customer = Customer.find_by(email: email)

        if customer.nil?
          customer = Customer.new(
            name: name,
            email: email,
            phone: phone_number,
            country: country,
            lead_source: 'Inbound',
            status: 'Pending',
            idea_description: description,
            preferred_calling_time: preferred_calling_time
          )
        end

        if customer.save
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
