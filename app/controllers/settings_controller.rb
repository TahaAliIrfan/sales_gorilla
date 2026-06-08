require "csv"

class SettingsController < ApplicationController
  layout "relay"
  before_action :require_login

  # Workspace tabs, ported from docs/design/relay-app/project/app/view-settings.jsx.
  # Branding/team/features are admin-gated (see #admin_tabs?); associates only see
  # profile + integrations. "features" is its own controller (Settings::Features)
  # reached via its route, but we render its tab link here for a unified bar.
  TABS = %w[profile branding team integrations features].freeze

  # GET /settings?tab=profile|branding|team|integrations
  def edit
    @user = current_user
    @tab  = TABS.include?(params[:tab]) ? params[:tab] : "profile"
    # Non-admins can't reach branding/team — fall back to profile.
    @tab = "profile" if %w[branding team].include?(@tab) && !helpers.admin_tabs?

    load_integration_state
    load_branding if @tab == "branding"
    load_team     if @tab == "team"
  end

  def update
    @user = current_user

    # Normalize phone number
    if params[:user][:phone_number].present?
      params[:user][:phone_number] = normalize_phone(params[:user][:phone_number])
    end

    if @user.update(user_params)
      redirect_to settings_path, notice: "Settings updated successfully."
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

    redirect_to settings_path, notice: "Google Calendar disconnected successfully."
  end

  def export_customers_with_deals
    unless current_user.admin?
      redirect_to settings_path, alert: "Only admins can export data."
      return
    end

    customers = Customer.joins(:deals).where(deals: { status: [ "won", "lost" ] }).distinct

    csv_data = CSV.generate(headers: true) do |csv|
      csv << [
        "Customer Name", "Email", "Phone", "Company", "Country",
        "Lead Source", "Platform", "Status",
        "Deal Title", "Deal Amount", "Deal Status", "Deal Expected Close Date", "Deal Closing Date",
        "Assigned To", "Customer Created At"
      ]

      customers.includes(:deals, :user).find_each do |customer|
        customer.deals.where(status: [ "won", "lost" ]).each do |deal|
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
            customer.created_at&.strftime("%Y-%m-%d")
          ]
        end
      end
    end

    send_data csv_data,
      filename: "customers_with_deals_#{Date.today.strftime('%Y%m%d')}.csv",
      type: "text/csv",
      disposition: "attachment"
  end

  private

  # Google Calendar connection state for the Integrations tab (and shown on
  # Profile too). Mirrors the original #edit logic.
  def load_integration_state
    if @user.google_auth_configured?
      @calendar_connected = GoogleCalendarService.new(@user).check_connection
    else
      @calendar_connected = false
    end
  end

  # Organization for the Branding tab form (posts to the existing
  # BrandingController#update endpoint).
  def load_branding
    @organization = current_organization
  end

  # User list for the Team & roles tab. Mirrors UsersController#index — scoped
  # to the current organization's members and its per-org system roles.
  def load_team
    @users = current_organization.users.order(:name)
    @roles = current_organization.roles.system_roles
                                 .order(hierarchy_level: :desc)
                                 .map { |r| { key: r.key, name: r.name } }
  end

  def user_params
    params.require(:user).permit(:phone_number)
  end

  def normalize_phone(phone)
    # Strip any whitespace
    cleaned_phone = phone.strip

    # Check if the phone already has a plus sign
    has_plus = cleaned_phone.start_with?("+")

    # Remove all non-digit characters
    digits_only = cleaned_phone.gsub(/\D/, "")

    # Add the plus sign back if it was there, or add it if it wasn't
    "+" + digits_only
  end
end
