class CustomerEmailFetchWorker
  include Sidekiq::Worker
  sidekiq_options retry: 3, queue: 'emails'

  def perform(customer_id, user_id)
    # Find the customer
    customer = Customer.find_by(id: customer_id)
    return unless customer

    # Find the user
    user = User.find_by(id: user_id)
    return unless user

    # Get the initial email count
    initial_email_count = customer.emails.count
    
    # Store the initial count in cache if not already stored
    Rails.cache.write("customer_#{customer.id}_email_count_before", initial_email_count) unless Rails.cache.exist?("customer_#{customer.id}_email_count_before")

    # Initialize the Gmail service with the user 
    gmail_service = GmailService.new(user)

    # Fetch emails for the customer
    emails = gmail_service.fetch_emails_for_customer(customer)


    customer.update(last_email_fetched_at: Time.now)

  end
end 