class CustomerGroupsController < ApplicationController
  layout "tenant"
  before_action :set_customer_group, only: [:show, :edit, :update, :destroy, :add_customer, :remove_customer]

  def index
    @customer_groups = policy_scope(CustomerGroup).order(created_at: :desc)
  end

  def show
    authorize @customer_group
    @customers = @customer_group.customers.order(:name)
    @available_customers = current_user.customers.where.not(id: @customers.pluck(:id)).order(:name)
  end

  def new
    @customer_group = CustomerGroup.new
    authorize @customer_group
  end

  def edit
    authorize @customer_group
  end

  def create
    @customer_group = current_user.customer_groups.build(customer_group_params)
    authorize @customer_group

    if @customer_group.save
      redirect_to @customer_group, notice: 'Customer group was successfully created.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @customer_group

    if @customer_group.update(customer_group_params)
      redirect_to @customer_group, notice: 'Customer group was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @customer_group
    @customer_group.destroy
    redirect_to customer_groups_url, notice: 'Customer group was successfully deleted.'
  end

  def add_customer
    authorize @customer_group
    customer = Customer.find(params[:customer_id])

    @customer_group.add_customer(customer)
    redirect_to @customer_group, notice: 'Customer added to group.'
  end

  def remove_customer
    authorize @customer_group
    customer = Customer.find(params[:customer_id])

    @customer_group.remove_customer(customer)
    redirect_to @customer_group, notice: 'Customer removed from group.'
  end

  private

  def set_customer_group
    @customer_group = CustomerGroup.find(params[:id])
  end

  def customer_group_params
    params.require(:customer_group).permit(:name, :description)
  end
end
