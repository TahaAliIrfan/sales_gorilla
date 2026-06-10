require "net/http"
require "uri"
require "json"

# Talks to Meta's Graph API for the Lead Ads integration. Two distinct phases:
#
#   1. Self-service connect (app-level): turn an OAuth `code` into a long-lived
#      user token, list the Pages the admin manages, and subscribe each Page to
#      the `leadgen` webhook field. Uses the shared app id/secret.
#
#   2. Lead retrieval (per-page): the `leadgen` webhook only sends ids, so we
#      call GET /{leadgen_id} with that Page's access token to fetch the actual
#      field_data (name/email/phone + custom answers).
#
# Mirrors the Net::HTTP style of MetaConversionsApiService. Every call returns a
# plain hash; network/HTTP errors are caught and returned as { error: ... }.
class MetaLeadAdsService
  GRAPH_VERSION = "v25.0".freeze
  GRAPH_HOST    = "https://graph.facebook.com".freeze

  # Scopes required for self-service Lead Ads. leads_retrieval + pages_* gate the
  # webhook subscription and lead fetch; ads_management is needed by some lead
  # forms. All require App Review for advanced access.
  OAUTH_SCOPES = %w[
    pages_show_list
    pages_read_engagement
    pages_manage_metadata
    leads_retrieval
    ads_management
  ].freeze

  class << self
    def app_id
      Rails.application.credentials.dig(:meta_app_id)
    end

    def app_secret
      Rails.application.credentials.dig(:meta_app_secret)
    end

    def configured?
      app_id.present? && app_secret.present?
    end

    # The Facebook Login dialog URL the admin is redirected to. `state` is our
    # signed CSRF/org token; `redirect_uri` must exactly match one registered in
    # the Meta App's "Valid OAuth Redirect URIs".
    def oauth_dialog_url(redirect_uri:, state:)
      query = URI.encode_www_form(
        client_id:    app_id,
        redirect_uri: redirect_uri,
        state:        state,
        scope:        OAUTH_SCOPES.join(","),
        response_type: "code"
      )
      "https://www.facebook.com/#{GRAPH_VERSION}/dialog/oauth?#{query}"
    end

    # OAuth code -> short-lived user access token.
    def exchange_code(code:, redirect_uri:)
      get("/oauth/access_token",
          client_id:     app_id,
          client_secret: app_secret,
          redirect_uri:  redirect_uri,
          code:          code)
    end

    # Short-lived user token -> long-lived user token (~60 days).
    def long_lived_user_token(short_token)
      get("/oauth/access_token",
          grant_type:        "fb_exchange_token",
          client_id:         app_id,
          client_secret:     app_secret,
          fb_exchange_token: short_token)
    end

    # Pages the user manages, each with its own (long-lived, when derived from a
    # long-lived user token) Page access token. Returns the raw `data` array.
    def list_pages(user_token)
      result = get("/me/accounts",
                   fields:       "id,name,access_token",
                   access_token: user_token)
      Array(result["data"])
    end

    # Subscribe a Page to the `leadgen` field so its leads hit our webhook.
    def subscribe_page(page_id:, page_token:)
      post("/#{page_id}/subscribed_apps",
           subscribed_fields: "leadgen",
           access_token:      page_token)
    end

    def unsubscribe_page(page_id:, page_token:)
      delete("/#{page_id}/subscribed_apps", access_token: page_token)
    end

    # Fetch a single lead's data. Returns the parsed lead object including
    # `field_data` (array of { name:, values: }).
    def fetch_lead(leadgen_id:, page_token:)
      get("/#{leadgen_id}",
          fields:       "id,created_time,field_data,ad_id,adset_id,campaign_id,form_id,platform",
          access_token: page_token)
    end

    private

    def get(path, **params)
      uri = URI.parse("#{GRAPH_HOST}/#{GRAPH_VERSION}#{path}")
      uri.query = URI.encode_www_form(params) if params.any?
      request(Net::HTTP::Get.new(uri.request_uri), uri)
    end

    def post(path, **params)
      uri = URI.parse("#{GRAPH_HOST}/#{GRAPH_VERSION}#{path}")
      req = Net::HTTP::Post.new(uri.request_uri)
      req.set_form_data(params)
      request(req, uri)
    end

    def delete(path, **params)
      uri = URI.parse("#{GRAPH_HOST}/#{GRAPH_VERSION}#{path}")
      uri.query = URI.encode_www_form(params) if params.any?
      request(Net::HTTP::Delete.new(uri.request_uri), uri)
    end

    def request(req, uri)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      response = http.request(req)
      body = JSON.parse(response.body) rescue {}

      unless response.is_a?(Net::HTTPSuccess)
        err = body.is_a?(Hash) ? body["error"] : nil
        Rails.logger.error("[MetaLeadAds] #{req.method} #{uri.path} -> #{response.code}: #{body}")
        return { "error" => err || { "message" => "HTTP #{response.code}" } }
      end

      body.is_a?(Hash) ? body : { "data" => body }
    rescue StandardError => e
      Rails.logger.error("[MetaLeadAds] #{req.method} #{uri.path} failed: #{e.message}")
      { "error" => { "message" => e.message } }
    end
  end
end
