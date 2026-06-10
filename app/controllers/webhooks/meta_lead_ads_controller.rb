require "openssl"

# Single global endpoint that receives Meta Lead Ads `leadgen` webhooks for ALL
# connected pages across ALL organizations. Meta sends every subscribed page's
# leads to this one URL, identifying the page by `page_id` in the payload — so
# we resolve the owning org via MetaPageConnection (page_id is the routing key).
#
# Lives on the root host (RootDomain), so there is no current tenant; org scope
# is established explicitly per lead. Persists a MetaInboundLead immediately and
# hands the slow Graph API fetch to ProcessMetaInboundLeadWorker.
module Webhooks
  class MetaLeadAdsController < ApplicationController
    skip_before_action :verify_authenticity_token

    # GET — Meta's one-time subscription handshake. Echo hub.challenge back only
    # when the verify token matches the one configured in the App dashboard.
    def verify
      if params["hub.mode"] == "subscribe" &&
         valid_verify_token?(params["hub.verify_token"])
        render plain: params["hub.challenge"].to_s
      else
        head :forbidden
      end
    end

    # POST — leadgen notification. Verify the signature, then enqueue each lead.
    # Always 200 on a well-formed, authentic request (even if a page is unknown)
    # so Meta doesn't retry/disable the subscription.
    def receive
      return head :unauthorized unless valid_signature?

      payload = parse_body
      return head :ok if payload.blank?

      each_leadgen_change(payload) do |page_id, value|
        ingest(page_id, value, payload)
      end

      head :ok
    end

    private

    def app_secret
      MetaLeadAdsService.app_secret
    end

    def verify_token
      Rails.application.credentials.dig(:meta_webhook_verify_token)
    end

    def valid_verify_token?(token)
      expected = verify_token.to_s
      expected.present? && ActiveSupport::SecurityUtils.secure_compare(token.to_s, expected)
    end

    # X-Hub-Signature-256: "sha256=" + HMAC-SHA256(raw_body, app_secret).
    def valid_signature?
      header = request.headers["X-Hub-Signature-256"].to_s
      return false if app_secret.blank? || header.blank?

      expected = "sha256=" + OpenSSL::HMAC.hexdigest("SHA256", app_secret, request.raw_post)
      ActiveSupport::SecurityUtils.secure_compare(header, expected)
    end

    def parse_body
      JSON.parse(request.raw_post)
    rescue JSON::ParserError
      nil
    end

    # Yields [page_id, change_value_hash] for every leadgen change in the payload.
    def each_leadgen_change(payload)
      Array(payload["entry"]).each do |entry|
        Array(entry["changes"]).each do |change|
          next unless change["field"] == "leadgen"
          value = change["value"] || {}
          page_id = value["page_id"] || entry["id"]
          yield(page_id, value) if page_id.present? && value["leadgen_id"].present?
        end
      end
    end

    def ingest(page_id, value, payload)
      connection = MetaPageConnection.for_page(page_id)
      unless connection
        Rails.logger.warn("[MetaLeadAds] webhook for unknown/inactive page #{page_id}")
        return
      end

      ActsAsTenant.with_tenant(connection.organization) do
        lead = MetaInboundLead.find_or_initialize_by(leadgen_id: value["leadgen_id"])
        return unless lead.new_record? # already received; ignore duplicate delivery

        lead.assign_attributes(
          organization:    connection.organization,
          page_id:         page_id,
          form_id:         value["form_id"],
          ad_id:           value["ad_id"],
          adset_id:        value["adgroup_id"] || value["adset_id"],
          campaign_id:     value["campaign_id"],
          status:          "received",
          webhook_payload: payload,
          received_at:     Time.current
        )
        lead.save!
        ProcessMetaInboundLeadWorker.perform_async(lead.id)
      end
    rescue ActiveRecord::RecordNotUnique
      # Concurrent delivery of the same leadgen_id — the unique index won the race.
      Rails.logger.info("[MetaLeadAds] duplicate leadgen_id #{value['leadgen_id']} ignored")
    end
  end
end
