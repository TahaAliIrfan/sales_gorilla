module Campaigns
  # Open inbound webhook for Meta / ad lead capture. Posts a lead and creates a
  # Customer in the org resolved from the request subdomain (acts_as_tenant).
  # Unauthenticated by design — every auth/tenant guard is skipped so external
  # services (Zapier/Make/Meta) can POST directly.
  class MetaInboundController < ApplicationController
    skip_before_action :verify_authenticity_token
    skip_before_action :require_login, raise: false
    skip_before_action :authorize_tenant_request!, raise: false
    skip_before_action :set_tasks_notification_counts, raise: false
    skip_before_action :set_notification_counts, raise: false

    def create
      # Org comes from the request subdomain via acts_as_tenant (e.g. a POST to
      # toasty.salesgorilla.app resolves the Toasty org). Guard against a missing
      # tenant so we return a clean 422 instead of a 500.
      org = ActsAsTenant.current_tenant
      unless org
        return render json: { success: false, errors: [ "Organization not found" ] }, status: :unprocessable_entity
      end

      raw_phone = params[:phone_number]
      phone = raw_phone =~ /\A\+\d{6,15}\z/ ? raw_phone : nil

      # Set the organization explicitly (acts_as_tenant would also auto-assign it
      # from the current tenant, but we make it unambiguous here).
      customer = Customer.new(
        organization: org,
        name: params[:name],
        email: params[:email],
        phone: phone,
        idea_description: params[:description],
        timezone: params[:timezone],
        preferred_calling_time: params[:preferred_time],
        lead_source: "Inbound",
        status: "Pending",
        meta_lead_id: params[:meta_lead_id],
        facebook_click_id: params[:facebook_click_id] || params[:fbclid],
        browser_id: params[:browser_id],
        meta_campaign_id: params[:meta_campaign_id],
        meta_adset_id: params[:meta_adset_id],
        meta_ad_id: params[:meta_ad_id]
      )

      if customer.save
        render json: { success: true, customer_id: customer.id }, status: :created
      else
        render json: { success: false, errors: customer.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end
end
