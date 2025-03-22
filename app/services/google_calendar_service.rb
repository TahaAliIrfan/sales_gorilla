require 'google/apis/calendar_v3'
require 'googleauth'

class GoogleCalendarService
  attr_reader :calendar_api

  def initialize(user)
    @user = user
    @calendar_api = Google::Apis::CalendarV3::CalendarService.new
    @calendar_api.authorization = user_credentials
  end

  def create_customer_followup_event(customer, followup_date, description)
    return { success: false, error: 'Google Calendar not connected' } unless @calendar_api.authorization

    event = Google::Apis::CalendarV3::Event.new(
      summary: "Follow up with #{customer.name}",
      description: description,
      start: {
        date_time: followup_date.to_datetime.rfc3339,
        time_zone: 'UTC'
      },
      end: {
        date_time: (followup_date.to_datetime + 30.minutes).rfc3339,
        time_zone: 'UTC'
      },
      reminders: {
        use_default: true
      }
    )

    begin
      result = @calendar_api.insert_event('primary', event)
      { success: true, event_id: result.id, html_link: result.html_link }
    rescue Google::Apis::Error => e
      Rails.logger.error("Failed to create Google Calendar event: #{e.message}")
      { success: false, error: e.message }
    end
  end

  # Check if calendar service is connected and working
  def check_connection
    return false unless @calendar_api.authorization

    begin
      # Try to fetch calendar list as a test
      @calendar_api.list_calendar_lists(max_results: 1)
      true
    rescue Google::Apis::Error => e
      Rails.logger.error("Google Calendar connection error: #{e.message}")
      false
    end
  end

  private

  def user_credentials
    # Check if the user has Google OAuth tokens
    return nil unless @user.google_token.present? && @user.google_refresh_token.present?

    # Create credentials from tokens
    creds = Google::Auth::UserRefreshCredentials.new(
      client_id: Rails.application.credentials.dig(:GOOGLE_CLIENT_ID),
      client_secret: Rails.application.credentials.dig(:GOOGLE_CLIENT_SECRET),
      refresh_token: @user.google_refresh_token,
      access_token: @user.google_token
    )

    # Check if token is expired and refresh if needed
    if @user.google_token_expires_at.nil? || @user.google_token_expires_at < Time.current
      begin
        creds.refresh!
        @user.update(
          google_token: creds.access_token,
          google_token_expires_at: Time.now + creds.expires_in.seconds
        )
      rescue => e
        Rails.logger.error("Failed to refresh Google token: #{e.message}")
        return nil
      end
    end

    creds
  end
end 