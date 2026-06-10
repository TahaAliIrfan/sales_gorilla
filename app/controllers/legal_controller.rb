require "openssl"
require "base64"

# Public legal pages on the root domain (no tenant, no login). Required for the
# Meta App going Live: a valid Privacy Policy URL, Terms of Service, and
# user-data deletion instructions.
class LegalController < ApplicationController
  layout "legal"
  skip_before_action :verify_authenticity_token, only: :data_deletion_callback

  def privacy; end
  def terms; end
  def data_deletion; end

  # Meta "Data Deletion Request Callback URL" endpoint. Meta POSTs a
  # `signed_request` (HMAC-signed with our app secret); we must verify it and
  # respond with JSON `{ url, confirmation_code }` pointing at a status page.
  # https://developers.facebook.com/docs/development/create-an-app/app-dashboard/data-deletion-callback
  def data_deletion_callback
    data = parse_signed_request(params[:signed_request].to_s)
    return head :bad_request unless data

    code = SecureRandom.hex(8)
    Rails.logger.info("[MetaDataDeletion] request fb_user_id=#{data['user_id']} code=#{code}")

    render json: {
      url: data_deletion_url(code: code),
      confirmation_code: code
    }
  end

  private

  # Verifies and decodes Meta's signed_request ("<sig>.<payload>", base64url).
  def parse_signed_request(signed)
    sig_b64, payload_b64 = signed.split(".", 2)
    return nil if sig_b64.blank? || payload_b64.blank?

    secret = MetaLeadAdsService.app_secret
    return nil if secret.blank?

    expected = OpenSSL::HMAC.digest("SHA256", secret, payload_b64)
    given    = base64_url_decode(sig_b64)
    return nil unless given && ActiveSupport::SecurityUtils.secure_compare(given, expected)

    JSON.parse(base64_url_decode(payload_b64))
  rescue StandardError
    nil
  end

  def base64_url_decode(str)
    Base64.urlsafe_decode64(str + ("=" * ((4 - (str.length % 4)) % 4)))
  rescue ArgumentError
    nil
  end
end
