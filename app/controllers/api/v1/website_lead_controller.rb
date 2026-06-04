module Api
  module V1
    class WebsiteLeadController < Api::V1::BaseController
      def create
        if params[:email].present?
          existing = Customer.find_by(email: params[:email])
          if existing
            existing.update!(updated_at: Time.current, repeat_lead: true)
            render json: { success: true, message: "Successfully updated" }, status: :ok
            return
          end

          @customer = Customer.new(
            name: params[:name],
            email: params[:email],
            phone: params[:phone_number],
            country: params[:country],
            lead_source: "Website",
            status: "Pending",
            idea_description: params[:description] || params[:message],
            # Meta-specific fields
            meta_lead_id: params[:meta_lead_id],
            facebook_click_id: params[:facebook_click_id] || params[:fbclid],
            browser_id: params[:browser_id],
            meta_campaign_id: params[:meta_campaign_id],
            meta_adset_id: params[:meta_adset_id],
            meta_ad_id: params[:meta_ad_id],
            # Ad click tracking
            gclid: params[:gclid],
            gbraid: params[:gbraid],
            wbraid: params[:wbraid],
            fbclid: params[:fbclid],
            msclkid: params[:msclkid],
            # UTM parameters
            utm_source: params[:utm_source],
            utm_medium: params[:utm_medium],
            utm_campaign: params[:utm_campaign],
            utm_term: params[:utm_term],
            utm_content: params[:utm_content],
            landing_page: params[:landing_page],
            traffic_source: params[:traffic_source]
          )
          if @customer.save
            render json: { success: true, message: "Successfully created" }, status: :created
          else
            render json: { success: false, errors: @customer.errors.full_messages }, status: :unprocessable_entity
          end
        else
          render json: { success: false, errors: "Unable to add" }, status: :unprocessable_entity
        end
      end
    end
  end
end
