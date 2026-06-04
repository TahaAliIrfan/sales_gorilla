require 'csv'

class SettingsController < ApplicationController
  layout "tenant"
  before_action :require_login
  
  def edit
    @user = current_user
    
    # Check if Google Calendar is actually accessible
    if @user.google_auth_configured?
      calendar_service = GoogleCalendarService.new(@user)
      @calendar_connected = calendar_service.check_connection
    else
      @calendar_connected = false
    end
  end

  def update
    @user = current_user
    
    # Normalize phone number
    if params[:user][:phone_number].present?
      params[:user][:phone_number] = normalize_phone(params[:user][:phone_number])
    end
    
    if @user.update(user_params)
      redirect_to settings_path, notice: 'Settings updated successfully.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def disconnect_google
    current_user.update(
      google_token: nil,
      google_refresh_token: nil,
      google_token_expires_at: nil
    )
    
    redirect_to settings_path, notice: 'Google Calendar disconnected successfully.'
  end

  def export_customers_with_deals
    unless current_user.admin?
      redirect_to settings_path, alert: 'Only admins can export data.'
      return
    end

    customers = Customer.joins(:deals).where(deals: { status: ['won', 'lost'] }).distinct

    csv_data = CSV.generate(headers: true) do |csv|
      csv << [
        'Customer Name', 'Email', 'Phone', 'Company', 'Country',
        'Lead Source', 'Platform', 'Status',
        'Deal Title', 'Deal Amount', 'Deal Status', 'Deal Expected Close Date', 'Deal Closing Date',
        'Assigned To', 'Customer Created At'
      ]

      customers.includes(:deals, :user).find_each do |customer|
        customer.deals.where(status: ['won', 'lost']).each do |deal|
          csv << [
            customer.name,
            customer.email,
            customer.phone,
            customer.company,
            customer.country,
            customer.lead_source,
            customer.platform,
            customer.status,
            deal.title,
            deal.amount,
            deal.status,
            deal.expected_close_date,
            deal.closing_date,
            customer.user&.name,
            customer.created_at&.strftime('%Y-%m-%d')
          ]
        end
      end
    end

    send_data csv_data,
      filename: "customers_with_deals_#{Date.today.strftime('%Y%m%d')}.csv",
      type: 'text/csv',
      disposition: 'attachment'
  end

  private
  
  def user_params
    params.require(:user).permit(:phone_number)
  end
  
  def normalize_phone(phone)
    # Strip any whitespace
    cleaned_phone = phone.strip
    
    # Check if the phone already has a plus sign
    has_plus = cleaned_phone.start_with?('+')
    
    # Remove all non-digit characters
    digits_only = cleaned_phone.gsub(/\D/, '')
    
    # Add the plus sign back if it was there, or add it if it wasn't
    '+' + digits_only
  end
  
  def require_login
    unless session[:user_id]
      flash[:error] = "You must be logged in to access this section"
      redirect_to root_path
    end
  end
end
