module Api
  module V1
    # Generic lead intake for admin-configured LeadWebhooks.
    # Zapier (or any source) POSTs to /api/v1/leads/:token with the
    # canonical field names below; the webhook config supplies lead_source.
    class LeadIntakeController < Api::V1::BaseController

      def create
        webhook = LeadWebhook.active.find_by(token: params[:token])
        unless webhook
          render json: { success: false, error: 'Unknown or inactive webhook' }, status: :not_found
          return
        end

        payload = incoming_payload

        if email.blank? && phone.blank?
          webhook.record_failure!(payload, 'Missing email and phone')
          render json: { success: false, error: 'email or phone is required' }, status: :unprocessable_entity
          return
        end

        if email.present? && (existing = Customer.find_by(email: email))
          existing.update!(updated_at: Time.current, repeat_lead: true)
          webhook.record_success!(payload)
          render json: { success: true, message: 'Successfully updated', repeat_lead: true, customer_id: existing.id }, status: :ok
          return
        end

        customer = Customer.new(customer_attributes(webhook))

        if customer.save
          webhook.record_success!(payload)
          render json: { success: true, message: 'Successfully created', customer_id: customer.id }, status: :created
        else
          webhook.record_failure!(payload, customer.errors.full_messages.join(', '))
          render json: { success: false, errors: customer.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def email
        params[:email].presence
      end

      def phone
        params[:phone].presence || params[:phone_number].presence
      end

      def customer_attributes(webhook)
        {
          name: params[:name] || params[:full_name],
          email: email,
          phone: phone,
          country: params[:country],
          lead_source: webhook.lead_source,
          status: 'Pending',
          idea_description: params[:description] || params[:message] || params[:idea_description],
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
        }
      end

      # Stored on the webhook for debugging Zap field mappings.
      def incoming_payload
        params.to_unsafe_h.except('controller', 'action', 'token', 'format', 'lead_intake')
      end
    end
  end
end
