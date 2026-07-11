class CustomerEmailFetchWorker
  include Sidekiq::Worker
  sidekiq_options retry: 2, queue: 'emails'

  SYNC_COOLDOWN = 5.minutes

  # user_id is accepted for backwards compatibility but ignored — emails are
  # always fetched from the customer's ASSIGNED user's Gmail.
  def perform(customer_id, _user_id = nil)
    customer = Customer.find_by(id: customer_id)
    return unless customer
    return unless customer.email.present?

    if customer.last_email_fetched_at.present? && customer.last_email_fetched_at > SYNC_COOLDOWN.ago
      return
    end

    user = customer.user
    return unless user&.google_auth_configured?

    gmail_service = GmailService.new(user)
    gmail_service.fetch_emails_for_customer(customer)

    customer.update(last_email_fetched_at: Time.current)
  rescue Google::Apis::AuthorizationError, Signet::AuthorizationError => e
    Rails.logger.warn("CustomerEmailFetchWorker: Auth error for customer #{customer_id}: #{e.message}")
  rescue => e
    Rails.logger.error("CustomerEmailFetchWorker: Failed for customer #{customer_id}: #{e.message}")
    raise
  end
end
