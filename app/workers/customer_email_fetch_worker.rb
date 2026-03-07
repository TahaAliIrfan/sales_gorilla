class CustomerEmailFetchWorker
  include Sidekiq::Worker
  sidekiq_options retry: 2, queue: 'emails'

  SYNC_COOLDOWN = 5.minutes

  def perform(customer_id, user_id)
    customer = Customer.find_by(id: customer_id)
    return unless customer
    return unless customer.email.present?

    if customer.last_email_fetched_at.present? && customer.last_email_fetched_at > SYNC_COOLDOWN.ago
      return
    end

    user = User.find_by(id: user_id)
    return unless user&.google_auth_configured?

    gmail_service = GmailService.new(user)
    gmail_service.fetch_emails_for_customer(customer)

    customer.update(last_email_fetched_at: Time.current)
  rescue Google::Apis::AuthorizationError, Signet::AuthorizationError => e
    Rails.logger.warn("CustomerEmailFetchWorker: Auth error for user #{user_id} / customer #{customer_id}: #{e.message}")
  rescue => e
    Rails.logger.error("CustomerEmailFetchWorker: Failed for customer #{customer_id}: #{e.message}")
    raise
  end
end
