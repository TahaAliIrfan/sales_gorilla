class CustomersController < ApplicationController
  layout 'dashboard'
  before_action :require_login
  before_action :set_customer, only: [:show, :edit, :update, :destroy, :update_status]
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  def index
    @users = User.all if current_user&.admin?
    
    # Check if this is an AJAX request for client-side filtering
    if request.xhr?
      @customers = policy_scope(Customer).includes(:user, :deals)
      
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
    @customers = policy_scope(Customer)
    
    # Apply filters using scopes
    if params[:user_id].present? && current_user&.admin?
      if params[:user_id] == 'unassigned'
        @customers = @customers.where(user_id: nil)
      else
        @customers = @customers.assigned_to(params[:user_id])
      end
    end
    @customers = @customers.search(params[:search])
    
    # Filter by status if provided (for all users, not just admins)
    if params[:status].present?
      Rails.logger.debug("Filtering by status: #{params[:status]}")
      @customers = @customers.where(status: params[:status])
    end
    
    # Filter by lead source if provided
    @customers = @customers.where(lead_source: params[:lead_source]) if params[:lead_source].present?
    
    # Apply sorting - always sort by created_at since we removed the sort column
    sort_direction = %w[asc desc].include?(params[:direction]) ? params[:direction] : 'desc'
    @customers = @customers.order("created_at #{sort_direction}")
    
    # Apply pagination with 20 items per page
    @customers = @customers.page(params[:page]).per(20)
    
    # Track filter state for the view
    @filter_applied = params[:search].present? || params[:user_id].present? || 
                      params[:status].present? || params[:lead_source].present?
  end

  def show
    authorize @customer
    @deals = @customer.deals
    @activities = @customer.customer_activities.recent.limit(10)
    @recordings = @customer.recordings.recent.limit(20)
    @tasks = @customer.tasks.order(due_date: :asc)
  end

  def new
    @customer = Customer.new
    authorize @customer
  end

  def create
    @customer = Customer.new(customer_params)

    if !current_user&.admin? || @customer.user_id.nil?
      @customer.user_id = current_user.id
    end
    
    authorize @customer

    # Validate required fields
    if @customer.name.blank?
      @customer.errors.add(:name, "can't be blank")
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
      render :new, status: :unprocessable_entity
    rescue => e
      @customer.errors.add(:base, "An unexpected error occurred: #{e.message}")
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @customer
  end

  def update
    authorize @customer
    
    # Log the original phone number
    Rails.logger.debug("Original phone number: #{@customer.phone}")
    Rails.logger.debug("New phone number from params: #{customer_params[:phone]}")
    
    # Assign attributes but don't save yet
    @customer.assign_attributes(customer_params)
    
    # Log the phone number after assignment
    Rails.logger.debug("Phone number after assignment: #{@customer.phone}")

    # Validate required fields
    if @customer.name.blank?
      @customer.errors.add(:name, "can't be blank")
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
    authorize @customer
    @customer.destroy
    redirect_to customers_path, notice: 'Customer was successfully deleted.'
  end

  def update_status
    @customer = Customer.find(params[:id])
    authorize @customer
    
    if @customer.update(status: params[:status])
      respond_to do |format|
        format.html { redirect_to @customer, notice: 'Status updated successfully.' }
        format.json { render json: { success: true } }
      end
    else
      respond_to do |format|
        format.html { redirect_to @customer, alert: 'Failed to update status.' }
        format.json { render json: { success: false, errors: @customer.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def update_communication_status
    @customer = Customer.find(params[:id])
    authorize @customer
    
    # Extract status type and value from params
    status_type = params[:status_type]
    status_value = params[:status_value]
    
    # Validate status type and value before updating
    valid_status_types = ['call_status', 'email_status', 'whatsapp_status', 'linkedin_status']
    valid_status_values = case status_type
                          when 'call_status'
                            Customer::CALL_STATUSES.values
                          when 'email_status'
                            Customer::EMAIL_STATUSES.values
                          when 'whatsapp_status'
                            Customer::WHATSAPP_STATUSES.values
                          when 'linkedin_status'
                            Customer::LINKEDIN_STATUSES.values
                          else
                            []
                          end
    
    unless valid_status_types.include?(status_type) && valid_status_values.include?(status_value)
      respond_to do |format|
        format.html { redirect_to @customer, alert: 'Invalid status type or value' }
        format.json { render json: { success: false, error: 'Invalid status type or value' }, status: :unprocessable_entity }
      end
      return
    end
    
    if @customer.update(status_type => status_value)
      respond_to do |format|
        format.html { redirect_to @customer, notice: "#{status_type.humanize} updated successfully" }
        format.json { render json: { success: true } }
      end
    else
      respond_to do |format|
        format.html { redirect_to @customer, alert: "Failed to update #{status_type.humanize}" }
        format.json { render json: { success: false, errors: @customer.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_customer
    @customer = Customer.find(params[:id])
  end

  def customer_params
    # Only permit parameters that are actually in the form
    permitted_params = [
      :name, :email, :phone, :address, :company, :notes,
      :lead_source, :linkedin_url, :ccr_link, :project_estimated_cost,
      :project_type, :idea_description, :country, :status, :call_status,
      :email_status, :whatsapp_status, :linkedin_status, :upwork_profile, :exhaust_status,
      :preferred_calling_time, :platform, :project_scope, :file
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
