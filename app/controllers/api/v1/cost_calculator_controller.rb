module Api
  module V1
    class CostCalculatorController < ApplicationController
      # Skip CSRF protection for API endpoints
      skip_before_action :verify_authenticity_token
      
      # POST /api/v1/cost_calculator
      def cost_calculator
        # Extract parameters from the request
        name = params[:name]
        email = params[:email]
        phone_number = params[:phone_number]
        country = params[:country]
        file_data = params[:file]
        
        # Validate required parameters
        unless name.present? && email.present?
          return render json: { error: "Name and email are required" }, status: :bad_request
        end
        
        # Find or create a customer based on email
        customer = Customer.find_by(email: email)
        
        if customer.nil?
          # Normalize phone number if provided
          normalized_phone = phone_number.present? ? normalize_phone(phone_number) : nil
          
          # Create a new customer
          customer = Customer.new(
            name: name,
            email: email,
            phone: normalized_phone,
            country: country,
            lead_source: 'Website',
            status: 'Pending'
          )
        end

        # Handle file attachment if present
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
            
            # Clean up the temp file
            temp_file.close
            temp_file.unlink
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
