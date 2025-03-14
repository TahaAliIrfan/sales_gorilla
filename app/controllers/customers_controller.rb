class CustomersController < ApplicationController
  layout 'dashboard'
  before_action :require_login
  before_action :set_customer, only: [:show, :edit, :update, :destroy]

  def index
    # Get all users for the filter dropdown
    @users = User.all
    
    # Check if this is an AJAX request for client-side filtering
    if request.xhr?
      # For AJAX requests, return all customers for client-side filtering
      @customers = Customer.all.includes(:user, :deals)
      render json: @customers.as_json(
        include: { 
          user: { only: [:id, :name] },
          deals: { only: [:id, :status] }
        },
        methods: [:active_deals_count]
      )
      return
    end
    
    # For regular requests, apply server-side filtering
    @customers = Customer.all
    
    # Apply filters using scopes
    @customers = @customers.assigned_to(params[:user_id])
    @customers = @customers.search(params[:search])
    
    # Apply sorting
    sort_column = %w[name email company].include?(params[:sort]) ? params[:sort] : 'name'
    sort_direction = %w[asc desc].include?(params[:direction]) ? params[:direction] : 'asc'
    @customers = @customers.order("#{sort_column} #{sort_direction}")
    
    # Track filter state for the view
    @filter_applied = params[:search].present? || params[:user_id].present?
  end

  def show
    @deals = @customer.deals
    @activities = @customer.customer_activities.recent.limit(10)
    @recordings = @customer.recordings.recent.limit(20)
  end

  def new
    @customer = Customer.new
  end

  def create
    # Log the parameters for debugging
    Rails.logger.debug("Customer params: #{params.inspect}")
    
    @customer = Customer.new(customer_params)
    
    # Log the customer object before saving
    Rails.logger.debug("Customer before save: #{@customer.attributes.inspect}")

    begin
      # Use save! to raise an exception on validation failure
      @customer.save!
      redirect_to @customer, notice: 'Customer was successfully created.'
    rescue ActiveRecord::RecordInvalid
      # Log validation errors for debugging
      Rails.logger.error("Customer validation failed: #{@customer.errors.full_messages.join(', ')}")
      render :new, status: :unprocessable_entity
    rescue => e
      # Log any unexpected errors
      Rails.logger.error("Error creating customer: #{e.message}")
      @customer.errors.add(:base, "An unexpected error occurred: #{e.message}")
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    begin
      # Use update! to raise an exception on validation failure
      @customer.update!(customer_params)
      redirect_to @customer, notice: 'Customer was successfully updated.'
    rescue ActiveRecord::RecordInvalid
      # Log validation errors for debugging
      Rails.logger.error("Customer update failed: #{@customer.errors.full_messages.join(', ')}")
      render :edit, status: :unprocessable_entity
    rescue => e
      # Log any unexpected errors
      Rails.logger.error("Error updating customer: #{e.message}")
      @customer.errors.add(:base, "An unexpected error occurred: #{e.message}")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @customer.destroy
    redirect_to customers_path, notice: 'Customer was successfully deleted.'
  end

  private

  def set_customer
    @customer = Customer.find(params[:id])
  end

  def customer_params
    # Only permit parameters that are actually in the form
    permitted_params = [
      :name, :email, :phone, :address, :company, :notes,
      :lead_source, :country_code, :linkedin_url, :ccr_link, :project_estimated_cost,
      :project_type, :idea_description, :country, :status, :call_status,
      :email_status, :whatsapp_status, :linkedin_status, :upwork_profile, :exhaust_status
    ]
    
    # Only admins can assign customers to users
    if current_user&.admin?
      permitted_params << :user_id
    end
    
    params.require(:customer).permit(permitted_params)
  end
  
  def require_login
    unless session[:user_id]
      flash[:error] = "You must be logged in to access this section"
      redirect_to root_path
    end
  end
end
