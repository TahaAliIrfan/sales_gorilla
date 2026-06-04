class CustomerFollowupWorker
  include Sidekiq::Worker

  sidekiq_options retry: 3, queue: "followups"

  def perform(customer_id, user_id, followup_date, notes, add_to_calendar)
    # Find the customer and user
    customer = Customer.find_by(id: customer_id)
    user = User.find_by(id: user_id)

    # Return early if customer or user not found
    return unless customer && user

    # Convert followup_date from string to Time if needed
    followup_date = Time.parse(followup_date) if followup_date.is_a?(String)

    # Log the followup scheduling attempt
    Rails.logger.info "Scheduling followup for customer #{customer.name} by user #{user.name} at #{followup_date}"

    # Process Google Calendar integration if enabled
    if add_to_calendar && user.google_auth_configured?
      # Create a Google Calendar event
      calendar_service = GoogleCalendarService.new(user)
      result = calendar_service.create_customer_followup_event(customer, followup_date, notes)

      if result[:success]
        customer.update(
          followup_date: followup_date,
          followup_notes: notes,
          google_calendar_event_id: result[:event_id],
          google_calendar_event_link: result[:html_link]
        )

        # Create a task for the follow-up
        task = Task.create!(
          user: user,
          customer: customer,
          title: "Follow up with #{customer.name}",
          description: notes,
          due_date: followup_date,
          priority: "Medium",
          status: "pending"
        )

        # Log successful scheduling
        Rails.logger.info "Successfully scheduled followup with Google Calendar for customer #{customer.name}"

        # Create an activity entry for the follow-up
        customer.customer_activities.create!(
          action: "follow_up_scheduled",
          details: "Follow-up scheduled for #{followup_date.strftime('%b %d, %Y at %I:%M %p')}",
          user_id: user.id
        )
      else
        # Log failure and fallback to regular task
        Rails.logger.error "Failed to create Google Calendar event: #{result[:error]}"

        # Fallback to creating just a task without calendar integration
        process_followup_without_calendar(customer, user, followup_date, notes)
      end
    else
      # Process followup without Google Calendar
      process_followup_without_calendar(customer, user, followup_date, notes)
    end
  end

  private

  def process_followup_without_calendar(customer, user, followup_date, notes)
    # Update customer with followup information
    customer.update(followup_date: followup_date, followup_notes: notes)

    # Create a task for the follow-up
    task = Task.create!(
      user: user,
      customer: customer,
      title: "Follow up with #{customer.name}",
      description: notes,
      due_date: followup_date,
      priority: "Medium",
      status: "pending"
    )

    # Create an activity entry for the follow-up
    customer.customer_activities.create!(
      action: "follow_up_scheduled",
      details: "Follow-up scheduled for #{followup_date.strftime('%b %d, %Y at %I:%M %p')} (without calendar)",
      user_id: user.id
    )

    # Log successful task creation
    Rails.logger.info "Successfully created followup task for customer #{customer.name} (without calendar integration)"
  end
end
