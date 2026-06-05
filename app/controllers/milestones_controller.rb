# frozen_string_literal: true

class MilestonesController < ApplicationController
  layout "relay"
  before_action :require_login
  before_action :set_customer
  before_action :set_milestone, only: [ :show, :edit, :update, :destroy, :mark_paid, :mark_unpaid ]

  def index
    @milestones = @customer.milestones.includes(:milestone_items, :user).order(created_at: :desc)
    authorize Milestone.new(customer: @customer)
  end

  def show
    authorize @milestone
  end

  def new
    @milestone = @customer.milestones.build(schedule_type: "milestone", status: "unpaid")
    @milestone.milestone_items.build(amount: 0, position: 0) if @milestone.milestone_items.empty?
    authorize @milestone
  end

  def create
    @milestone = @customer.milestones.build(milestone_params)
    @milestone.user = current_user
    authorize @milestone

    if @milestone.save
      redirect_to customer_milestone_path(@customer, @milestone), notice: "Milestone created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @milestone
  end

  def update
    authorize @milestone

    if @milestone.update(milestone_params)
      redirect_to customer_milestone_path(@customer, @milestone), notice: "Milestone updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @milestone
    @milestone.destroy
    redirect_to customer_milestones_path(@customer), notice: "Milestone deleted successfully."
  end

  def mark_paid
    authorize @milestone
    @milestone.mark_paid!
    redirect_back fallback_location: customer_milestones_path(@customer), notice: "Milestone marked as paid."
  end

  def mark_unpaid
    authorize @milestone
    @milestone.mark_unpaid!
    redirect_back fallback_location: customer_milestones_path(@customer), notice: "Milestone marked as unpaid."
  end

  private

  def set_customer
    @customer = policy_scope(Customer).find(params[:customer_id])
  end

  def set_milestone
    @milestone = @customer.milestones.find(params[:id])
  end

  def milestone_params
    params.require(:milestone).permit(
      :name, :total_amount, :schedule_type, :currency, :notes,
      milestone_items_attributes: [ :id, :description, :amount, :due_date, :position, :_destroy ]
    )
  end
end
