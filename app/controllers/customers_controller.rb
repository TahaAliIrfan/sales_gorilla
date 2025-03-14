class CustomersController < ApplicationController
  layout 'dashboard'
  before_action :require_login
  before_action :set_customer, only: [:show, :edit, :update, :destroy]

  def index
    @customers = Customer.all
  end

  def show
    @deals = @customer.deals
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
    permitted_params = [:name, :email, :phone, :address, :company, :notes]
    
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
