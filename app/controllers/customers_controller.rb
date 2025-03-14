class CustomersController < ApplicationController
  layout 'dashboard'
  before_action :require_login
  before_action :set_customer, only: [:show, :edit, :update, :destroy]

  def index
    # Get all users for the filter dropdown (only for admins)
    @users = User.all if current_user&.admin?
    
    # Check if this is an AJAX request for client-side filtering
    if request.xhr?
      # For AJAX requests, return filtered customers based on user role
      if current_user&.admin?
        @customers = Customer.all.includes(:user, :deals)
      else
        @customers = Customer.where(user_id: current_user.id).includes(:user, :deals)
      end
      
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
    if current_user&.admin?
      @customers = Customer.all
    else
      @customers = Customer.where(user_id: current_user.id)
    end
    
    # Apply filters using scopes
    @customers = @customers.assigned_to(params[:user_id]) if params[:user_id].present? && current_user&.admin?
    @customers = @customers.search(params[:search])
    
    # Apply sorting
    sort_column = %w[name email company].include?(params[:sort]) ? params[:sort] : 'name'
    sort_direction = %w[asc desc].include?(params[:direction]) ? params[:direction] : 'asc'
    @customers = @customers.order("#{sort_column} #{sort_direction}")
    
    # Track filter state for the view
    @filter_applied = params[:search].present? || params[:user_id].present?
  end

  def show
    # Check if user has permission to view this customer
    unless current_user&.admin? || @customer.user_id == current_user&.id
      flash[:error] = "You don't have permission to view this customer"
      redirect_to customers_path
      return
    end
    
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
    
    # Automatically assign the current user to the customer if not an admin
    # or if no user_id was specified
    if !current_user&.admin? || @customer.user_id.nil?
      @customer.user_id = current_user.id
    end
    
    # Log the customer object before saving
    Rails.logger.debug("Customer before save: #{@customer.attributes.inspect}")

    # Validate required fields
    if @customer.name.blank?
      @customer.errors.add(:name, "can't be blank")
    end
    
    if @customer.email.blank? && @customer.phone.blank?
      @customer.errors.add(:base, "Either email or phone must be provided")
      @customer.errors.add(:email, "or phone must be provided")
      @customer.errors.add(:phone, "or email must be provided")
    end
    
    if @customer.errors.any?
      render :new, status: :unprocessable_entity
      return
    end

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
    # Check if user has permission to edit this customer
    unless current_user&.admin? || @customer.user_id == current_user&.id
      flash[:error] = "You don't have permission to edit this customer"
      redirect_to customers_path
      return
    end
  end

  def update
    # Check if user has permission to update this customer
    unless current_user&.admin? || @customer.user_id == current_user&.id
      flash[:error] = "You don't have permission to update this customer"
      redirect_to customers_path
      return
    end
    
    # Assign attributes but don't save yet
    @customer.assign_attributes(customer_params)
    
    # Validate required fields
    if @customer.name.blank?
      @customer.errors.add(:name, "can't be blank")
    end
    
    if @customer.email.blank? && @customer.phone.blank?
      @customer.errors.add(:base, "Either email or phone must be provided")
      @customer.errors.add(:email, "or phone must be provided")
      @customer.errors.add(:phone, "or email must be provided")
    end
    
    if @customer.errors.any?
      render :edit, status: :unprocessable_entity
      return
    end
    
    begin
      # Use save! to raise an exception on validation failure
      @customer.save!
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
    # Check if user has permission to delete this customer
    unless current_user&.admin? || @customer.user_id == current_user&.id
      flash[:error] = "You don't have permission to delete this customer"
      redirect_to customers_path
      return
    end
    
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
