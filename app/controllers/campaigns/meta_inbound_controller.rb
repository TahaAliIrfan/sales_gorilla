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
        facebook_click_id: resolved_fbc,
        browser_id: params[:browser_id] || cookies[:_fbp],
        meta_campaign_id: params[:meta_campaign_id],
        meta_adset_id: params[:meta_adset_id],
        meta_ad_id: params[:meta_ad_id],
        # Address identifiers Meta hashes for matching (ct/st/zp/country).
        city: params[:city],
        state: params[:state],
        zip: params[:zip],
        country: params[:country],
        # Meta CAPI "website" Lead event match-quality fields. Prefer values the
        # caller passed explicitly (a server-to-server relay like Zapier knows the
        # real browser context); fall back to this request when the browser POSTs
        # the form directly here.
        client_ip_address: params[:client_ip_address],
        client_user_agent: params[:client_user_agent],
        event_source_url: params[:event_source_url]
      )

      if customer.save
        render json: { success: true, customer_id: customer.id }, status: :created
      else
        render json: { success: false, errors: customer.errors.full_messages }, status: :unprocessable_entity
      end
    end

    private

    # The Meta click identifier (_fbc). Prefer an already-formed fbc value (passed
    # explicitly or read from the _fbc cookie when the browser POSTs directly).
    # Otherwise build it from the raw fbclid using Meta's documented format:
    # fb.<subdomainIndex>.<creationTimeMs>.<fbclid>.
    def resolved_fbc
      explicit = params[:fbc].presence || params[:facebook_click_id].presence || cookies[:_fbc].presence
      return explicit if explicit

      fbclid = params[:fbclid].presence
      return nil if fbclid.blank?

      "fb.1.#{(Time.now.to_f * 1000).to_i}.#{fbclid}"
    end
  end
end
