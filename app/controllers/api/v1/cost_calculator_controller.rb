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
        if params[:lead_source].present?
          lead_source = params[:lead_source]
        else
          lead_source = 'CCR'
        end

        customer = Customer.find_by(email: email)
        
        if customer.nil?
          # Create a new customer
          customer = Customer.new(
            name: name,
            email: email,
            phone: phone_number,
            country: country,
            lead_source: lead_source,
            status: 'Pending'
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
    end
  end
end
