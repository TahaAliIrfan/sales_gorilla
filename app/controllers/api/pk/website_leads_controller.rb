module Api
  module Pk
    class WebsiteLeadsController < Api::Pk::BaseController
      def create
        if params[:preferred_time].present?
          preferred_calling_time = parse_preferred_time(params[:preferred_time])
        else
          preferred_calling_time = "Not Applicable"
        end

        if params[:email].blank? && params[:phone].blank?
          render json: { success: false, error: "Email or phone is required" }, status: :unprocessable_entity
          return
        end

        if params[:email].present?
          existing = Customer.find_by(email: params[:email])
          if existing
            existing.update!(updated_at: Time.current, repeat_lead: true)
            render json: { success: true, message: "Lead already exists, marked as repeat" }, status: :ok
            return
          end
        end

        if params[:phone_number].present?
          phone = params[:phone_number]
        else
          phone = params[:phone]
        end

        customer = Customer.new(
          name: params[:name],
          email: params[:email],
          phone: phone,
          idea_description: params[:message],
          lead_source: "ODOO_PK",
          status: "Pending",
          # Meta-specific fields
          meta_lead_id: params[:meta_lead_id],
          facebook_click_id: params[:facebook_click_id] || params[:fbclid],
          browser_id: params[:browser_id],
          meta_campaign_id: params[:meta_campaign_id],
          meta_adset_id: params[:meta_adset_id],
          meta_ad_id: params[:meta_ad_id],
          # Meta-specific fields
          preferred_calling_time: preferred_calling_time
        )

        if customer.save
          render json: { success: true, message: "Lead created successfully" }, status: :created
        else
          render json: { success: false, errors: customer.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

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

          "#{formatted_time} (#{formatted_offset})"
        rescue => e
          Rails.logger.warn("Failed to parse preferred_time '#{timestamp}': #{e.message}")
          # Return the original value if parsing fails
          timestamp
        end
      end
    end
  end
end
