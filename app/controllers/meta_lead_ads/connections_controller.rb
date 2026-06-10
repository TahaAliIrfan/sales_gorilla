# Self-service Facebook Lead Ads connect flow. Lives on the ROOT host (like the
# Google OAuth callback) because Meta requires a single fixed redirect URI that
# can't vary per tenant subdomain — so the org is carried through a signed
# `state` param rather than the subdomain.
#
#   connect  -> redirect the admin to Facebook's OAuth dialog
#   callback -> exchange the code, list the admin's Pages, subscribe each to the
#               `leadgen` webhook, and persist a MetaPageConnection per page
#
# After connecting, the admin manages per-page lead sources / disconnects back
# on their tenant settings page (Settings::MetaPageConnectionsController).
module MetaLeadAds
  class ConnectionsController < ApplicationController
    layout "marketing"
    before_action :require_login

    # GET /meta_lead_ads/connect?org=<subdomain>
    def connect
      org = Organization.find_by(subdomain: params[:org].to_s)
      return deny unless org && can_administer?(org)
      return redirect_with_error(org, "Meta integration is not configured.") unless MetaLeadAdsService.configured?

      nonce = SecureRandom.hex(16)
      session[:meta_lead_ads_nonce] = nonce
      state = sign_state(org_id: org.id, user_id: current_user.id, nonce: nonce)

      redirect_to MetaLeadAdsService.oauth_dialog_url(redirect_uri: callback_url, state: state),
                  allow_other_host: true
    end

    # GET /meta_lead_ads/callback?code=...&state=...
    def callback
      return deny if params[:error].present?

      data = verify_state(params[:state])
      return deny unless data && data[:user_id] == current_user&.id

      org = Organization.find_by(id: data[:org_id])
      return deny unless org && can_administer?(org)

      connected = connect_pages(org, params[:code])
      if connected.zero?
        redirect_with_error(org, "No Facebook Pages could be connected. Make sure you manage a Page with Lead Ads.")
      else
        redirect_to tenant_settings_url(org),
                    allow_other_host: true,
                    notice: "Connected #{connected} Facebook #{'Page'.pluralize(connected)} for Lead Ads."
      end
    end

    private

    # Exchanges the OAuth code, subscribes every manageable page to leadgen and
    # upserts a MetaPageConnection. Returns the number of pages connected.
    def connect_pages(org, code)
      short = MetaLeadAdsService.exchange_code(code: code, redirect_uri: callback_url)
      return 0 if short["error"] || short["access_token"].blank?

      long = MetaLeadAdsService.long_lived_user_token(short["access_token"])
      user_token = long["access_token"].presence || short["access_token"]

      pages = MetaLeadAdsService.list_pages(user_token)
      return 0 if pages.empty?

      ActsAsTenant.with_tenant(org) do
        ensure_feature_enabled(org)
        pages.count { |page| subscribe_and_store(org, page) }
      end
    end

    def subscribe_and_store(org, page)
      page_id, page_token, page_name = page.values_at("id", "access_token", "name")
      return false if page_id.blank? || page_token.blank?

      result = MetaLeadAdsService.subscribe_page(page_id: page_id, page_token: page_token)
      return false if result["error"]

      connection = MetaPageConnection.find_or_initialize_by(page_id: page_id)
      connection.assign_attributes(
        organization:      org,
        page_name:         page_name,
        page_access_token: page_token,
        status:            "active",
        last_error:        nil,
        subscribed_at:     Time.current
      )
      connection.lead_source = "Inbound" if connection.lead_source.blank?
      connection.save!
      true
    end

    # Make sure the feature row exists and is on, so the webhook is honored and
    # the settings card reflects the connection.
    def ensure_feature_enabled(org)
      feature = org.features.find_or_initialize_by(key: "meta_lead_ads")
      feature.provider = "meta" if feature.provider.blank?
      feature.enabled = true
      feature.save!
    end

    def can_administer?(org)
      membership = current_user&.membership_for(org)
      UserContext.new(user: current_user, organization: org, membership: membership).can_administer?
    end

    # ---- state signing (CSRF + org binding) --------------------------------

    def sign_state(payload)
      verifier.generate(payload, expires_in: 15.minutes, purpose: :meta_lead_ads_oauth)
    end

    def verify_state(token)
      return nil if token.blank?
      data = verifier.verify(token, purpose: :meta_lead_ads_oauth)
      return nil unless data.is_a?(Hash)
      return nil unless ActiveSupport::SecurityUtils.secure_compare(
        data[:nonce].to_s, session[:meta_lead_ads_nonce].to_s
      )
      session.delete(:meta_lead_ads_nonce)
      data
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      nil
    end

    def verifier
      Rails.application.message_verifier(:meta_lead_ads)
    end

    # ---- URL helpers -------------------------------------------------------

    def callback_url
      meta_lead_ads_callback_url(host: root_host)
    end

    def tenant_settings_url(org)
      settings_features_url(host: tenant_host(org.subdomain))
    end

    # Replace the current host's subdomain with the tenant's (mirrors
    # OrganizationsController#tenant_host).
    def tenant_host(subdomain)
      parts = request.host.split(".")
      parts.shift if parts.first.in?(%w[www admin app api crm]) || parts.length > 2
      "#{subdomain}.#{parts.join('.')}"
    end

    def redirect_with_error(org, message)
      redirect_to tenant_settings_url(org), allow_other_host: true, alert: message
    end

    def deny
      redirect_to organizations_url(host: root_host), allow_other_host: true,
                  alert: "We couldn't verify that Facebook connection request."
    end
  end
end
