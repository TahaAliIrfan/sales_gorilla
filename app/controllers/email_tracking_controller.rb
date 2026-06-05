# Public endpoint hit by the tracking pixel embedded in sent emails. Recipients
# (or their email-client image proxies) request /e/o/<token>.gif when the
# message is rendered; we record the open and return a 1x1 transparent GIF.
#
# Always returns 200 + the image — regardless of whether the token matches an
# email — so attackers can't enumerate valid tokens by status code.
class EmailTrackingController < ActionController::API
  # The 43-byte payload of a 1×1 transparent GIF89a. Cached in memory as a
  # binary string and served from every request.
  PIXEL_GIF = "GIF89a\x01\x00\x01\x00\x80\x00\x00\x00\x00\x00\xff\xff\xff!\xf9\x04\x01\x00\x00\x00\x00,\x00\x00\x00\x00\x01\x00\x01\x00\x00\x02\x02D\x01\x00;".b.freeze

  def open
    token = params[:token].to_s
    record_open_async(token) if token.present?

    # Cache-busting + no-cache headers so the image is re-fetched on every
    # render (image proxies like Gmail still cache, but we minimize on our end).
    response.headers["Cache-Control"] = "no-store, no-cache, must-revalidate, private"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "0"

    send_data PIXEL_GIF, type: "image/gif", disposition: "inline"
  end

  private

  def record_open_async(token)
    # Inline lookup-and-update is cheap (single indexed query + one UPDATE).
    # If this ever shows up in slow logs, move it into a Sidekiq job.
    ActsAsTenant.without_tenant do
      email = Email.find_by(tracking_token: token)
      return unless email
      email.record_open!
    end
  rescue => e
    Rails.logger.warn("[EmailTracking] open recording failed for token=#{token.inspect}: #{e.message}")
  end
end
