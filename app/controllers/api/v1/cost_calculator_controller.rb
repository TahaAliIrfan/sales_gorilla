module Api
  module V1
    class CostCalculatorController < Api::V1::BaseController

      def inbound_lead
        name = params[:name]
        email = params[:email]
        phone_number = params[:phone_number]
        country = params[:country]
        description = params[:description] || nil
        preferred_calling_time = parse_preferred_time(params[:preferred_time])
        lead_source = params[:lead_source] || 'Inbound'

        customer = Customer.find_by(email: email)

        if customer.present?
          customer.update!(created_at: Time.current, repeat_lead: true)
          render json: { success: true, message: "Successfully updated" }, status: :ok
        else
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
            facebook_click_id: params[:facebook_click_id] || params[:fbclid],
            browser_id: params[:browser_id],
            meta_campaign_id: params[:meta_campaign_id],
            meta_adset_id: params[:meta_adset_id],
            meta_ad_id: params[:meta_ad_id],
            **tracking_params
          )

          if customer.save
            if customer.phone.present?
              phone_without_plus = customer.phone.gsub(/\A\+/, '')
              whatsapp_chat_id = "#{phone_without_plus}@c.us"
              customer.update!(whatsapp_chat_id: whatsapp_chat_id)
            end
            render json: { success: true, message: "Successfully added" }, status: :ok
          end
        end
      end

      def init_estimates
        contact_info = params[:contact] || {}
        name = contact_info[:name]
        email = contact_info[:email]
        phone_number = contact_info[:phone_number]
        gclid = params[:gclid]

        if name.blank? || email.blank?
          render json: { success: false, error: "Name and email are required" }, status: :unprocessable_entity
          return
        end

        begin
          customer = Customer.find_by(email: email)

          phone_without_plus = phone_number.gsub(/\A\+/, '')
          whatsapp_chat_id = "#{phone_without_plus}@c.us"

          if customer.present?
            # Update existing customer
            customer.update!(
              name: name,
              phone: phone_number,
              repeat_lead: true,
              lead_source: 'CCR',
              created_at: Time.current,
              gclid: gclid,
              whatsapp_chat_id: whatsapp_chat_id,
              **tracking_params
            )
          else
            # Create new customer
            customer = Customer.create!(
              name: name,
              email: email,
              phone: phone_number,
              lead_source: 'CCR',
              gclid: gclid,
              idea_description: params[:description],
              whatsapp_chat_id: whatsapp_chat_id,
              **tracking_params
            )
          end

          # Find the first admin or manager user to assign the estimate to
          default_user = User.joins(:role_assignments)
                            .where(role_assignments: { role_id: Role.where(key: ['admin', 'manager']).pluck(:id) })
                            .first || User.first

          # Extract and convert parameters to proper types
          total_hours = params[:totalHours].to_i
          hourly_rate = params[:hourlyRate].present? ? params[:hourlyRate].to_f : 20.0
          estimated_cost = params[:estimatedCost].to_f

          Rails.logger.info("Converted params - total_hours: #{total_hours}, hourly_rate: #{hourly_rate}, estimated_cost: #{estimated_cost}")

          # Check if an init status estimate already exists for this customer
          existing_estimate = CostEstimate.find_by(
            customer_id: customer.id,
            status: CostEstimate::STATUSES[:init]
          )

          if existing_estimate
            # Update existing init estimate
            existing_estimate.update!(
              application_types: params[:applicationTypes]&.to_json,
              scale: params[:projectScale],
              description: params[:description] || "Cost estimate from website",
              proposed_features: params[:features]&.to_json,
              total_hours: total_hours,
              hourly_rate: hourly_rate,
              total_cost: estimated_cost
            )
            cost_estimate = existing_estimate
          else
            # Create new cost estimate with init status
            cost_estimate = CostEstimate.create!(
              customer_id: customer.id,
              user_id: default_user.id,
              application_types: params[:applicationTypes]&.to_json,
              scale: params[:projectScale],
              description: params[:description] || "Cost estimate from website",
              proposed_features: params[:features]&.to_json,
              total_hours: total_hours,
              hourly_rate: hourly_rate,
              total_cost: estimated_cost,
              status: CostEstimate::STATUSES[:init]
            )
          end

          Rails.logger.info("Init cost estimate #{cost_estimate.id} created/updated for customer #{customer.id}")

          render json: {
            success: true,
            message: "Initial cost estimate saved successfully.",
            customer_id: customer.id,
            estimate_id: cost_estimate.id
          }, status: :ok
        rescue => e
          Rails.logger.error("Error creating init cost estimate: #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
          render json: {
            success: false,
            error: "Failed to process initial estimate: #{e.message}"
          }, status: :internal_server_error
        end
      end

      def submit_estimate
        contact_info = params[:contact] || {}
        name = contact_info[:name]
        email = contact_info[:email]
        phone_number = contact_info[:phone_number]
        gclid = params[:gclid]

        if name.blank? || email.blank?
          render json: { success: false, error: "Name and email are required" }, status: :unprocessable_entity
          return
        end

        begin
          # Find or create customer
          customer = Customer.find_by(email: email)

          if customer.present?
            # Update existing customer
            customer.update!(
              name: name,
              phone: phone_number,
              lead_source: 'CCR',
              gclid: params[:gclid],
              **tracking_params
            )
          else
            # Create new customer
            customer = Customer.create!(
              name: name,
              email: email.downcase,
              phone: phone_number,
              lead_source: 'CCR',
              status: 'Pending',
              gclid: params[:gclid],
              idea_description: params[:description],
              repeat_lead: false,
              **tracking_params
            )
            Rails.logger.info("Created new customer #{customer.id}")
          end

          # Find the first admin or manager user to assign the estimate to
          default_user = User.joins(:role_assignments)
                            .where(role_assignments: { role_id: Role.where(key: ['admin', 'manager']).pluck(:id) })
                            .first || User.first

          # Check if an init status estimate already exists for this customer
          existing_init_estimate = CostEstimate.find_by(
            customer_id: customer.id,
            status: CostEstimate::STATUSES[:init]
          )

          if existing_init_estimate
            # Update the existing init estimate to final status
            cost_estimate = existing_init_estimate
            cost_estimate.update!(
              application_types: params[:applicationTypes]&.to_json,
              scale: params[:projectScale],
              description: params[:description] || "Cost estimate from website",
              features_json: params[:features]&.to_json,
              total_hours: params[:totalHours],
              hourly_rate: params[:hourlyRate],
              total_cost: params[:estimatedCost],
              status: CostEstimate::STATUSES[:final]
            )
          else
            # Create new cost estimate with final status
            cost_estimate = CostEstimate.new(
              customer_id: customer.id,
              user_id: default_user.id,
              application_types: params[:applicationTypes]&.to_json,
              scale: params[:projectScale],
              description: params[:description] || "Cost estimate from website",
              features_json: params[:features]&.to_json,
              total_hours: params[:totalHours],
              hourly_rate: params[:hourlyRate],
              total_cost: params[:estimatedCost],
              status: CostEstimate::STATUSES[:final]
            )
            cost_estimate.save!
          end

          if cost_estimate.persisted?

            # Queue background job to generate and send PDF via WhatsApp
            job_id = ::SendCostEstimatePdfJob.perform_async(cost_estimate.id)

            Rails.logger.info("Cost estimate #{cost_estimate.id} created and PDF job #{job_id} queued for customer #{customer.id}")

            render json: {
              success: true,
              message: "Cost estimate submitted successfully. PDF will be sent to your WhatsApp shortly.",
              customer_id: customer.id,
              estimate_id: cost_estimate.id,
              pdf_job_queued: job_id.present?
            }, status: :created
          else
            render json: {
              success: false,
              errors: cost_estimate.errors.full_messages
            }, status: :unprocessable_entity
          end
        rescue => e
          Rails.logger.error("Error creating cost estimate: #{e.message}")
          Rails.logger.error(e.backtrace.join("\n"))
          render json: {
            success: false,
            error: "Failed to process estimate: #{e.message}"
          }, status: :internal_server_error
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

      def tracking_params
        {
          gclid: params[:gclid],
          gbraid: params[:gbraid],
          wbraid: params[:wbraid],
          fbclid: params[:fbclid],
          msclkid: params[:msclkid],
          utm_source: params[:utm_source],
          utm_medium: params[:utm_medium],
          utm_campaign: params[:utm_campaign],
          utm_term: params[:utm_term],
          utm_content: params[:utm_content],
          landing_page: params[:landing_page],
          traffic_source: params[:traffic_source]
        }.compact
      end
    end
  end
end
