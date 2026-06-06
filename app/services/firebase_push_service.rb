# Sends push notifications via Firebase Cloud Messaging (FCM HTTP v1 API).
#
# Requires a Firebase service-account JSON stored in credentials under the
# top-level `:firebase` key (a Hash with the standard service-account fields:
# type, project_id, private_key, client_email, etc.). If the credentials
# aren't configured, send! returns { success: false, error: "..." } and the
# caller is expected to no-op — push is a best-effort side channel.
#
# Usage:
#   FirebasePushService.new.send_to_token(
#     token: user.fcm_token,
#     title: 'New WhatsApp message',
#     body:  "#{customer.name} has sent you a message",
#     data:  { customer_id: customer.id.to_s }
#   )
require 'googleauth'
require 'net/http'
require 'json'
require 'stringio'

class FirebasePushService
  FCM_SCOPE = 'https://www.googleapis.com/auth/firebase.messaging'.freeze

  def initialize
    @service_account = Rails.application.credentials.dig(:firebase)
  end

  def configured?
    @service_account.present? &&
      @service_account[:project_id].present? &&
      @service_account[:client_email].present? &&
      @service_account[:private_key].present?
  end

  # Send a notification to a single FCM device token. Returns a result hash.
  def send_to_token(token:, title:, body:, data: {})
    return { success: false, error: 'FCM token is missing' }   if token.blank?
    return { success: false, error: 'FCM is not configured' }  unless configured?

    payload = {
      message: {
        token: token,
        notification: { title: title, body: body },
        data: stringify_values(data)
      }
    }

    response = post_to_fcm(payload)
    handle_response(response)
  rescue StandardError => e
    Rails.logger.error("[FCM] send_to_token error: #{e.class} #{e.message}")
    { success: false, error: e.message }
  end

  private

  # FCM requires every value in the `data` block to be a string.
  def stringify_values(hash)
    hash.transform_values { |v| v.is_a?(String) ? v : v.to_s }
  end

  def project_id
    @service_account[:project_id]
  end

  def access_token
    credentials = ::Google::Auth::ServiceAccountCredentials.make_creds(
      json_key_io: StringIO.new(@service_account.to_h.to_json),
      scope: FCM_SCOPE
    )
    credentials.fetch_access_token!['access_token']
  end

  def post_to_fcm(payload)
    uri = URI.parse("https://fcm.googleapis.com/v1/projects/#{project_id}/messages:send")

    req = Net::HTTP::Post.new(uri)
    req['Authorization'] = "Bearer #{access_token}"
    req['Content-Type']  = 'application/json'
    req.body = payload.to_json

    Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(req) }
  end

  def handle_response(response)
    if response.is_a?(Net::HTTPSuccess)
      { success: true, body: safe_json(response.body) }
    else
      Rails.logger.error("[FCM] non-2xx (#{response.code}): #{response.body.to_s.truncate(300)}")
      { success: false, error: "FCM responded #{response.code}" }
    end
  end

  def safe_json(body)
    JSON.parse(body)
  rescue StandardError
    body
  end
end
