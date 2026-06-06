# Publicly-accessible endpoint that 302-redirects to the underlying S3 file
# behind a tamper-proof Active Storage signed_id.
#
# Used as the Media URL in Twilio Content templates:
#   https://crm.tecaudex.com/wa/media/{{1}}
# where {{1}} is `ActiveStorage::Blob#signed_id`. This gives templates a stable
# URL prefix (which Twilio's Content Builder accepts) while still letting us
# generate per-customer media at send time.
class WhatsappMediaController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :require_login, raise: false

  def show
    blob = ActiveStorage::Blob.find_signed!(params[:signed_id])
    redirect_to blob.url(expires_in: 1.hour, disposition: 'inline'),
                allow_other_host: true,
                status: :found
  rescue ActiveSupport::MessageVerifier::InvalidSignature,
         ActiveRecord::RecordNotFound
    head :not_found
  end
end
