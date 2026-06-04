# frozen_string_literal: true

class MilestoneItemsController < ApplicationController
  layout "tenant"
  before_action :require_login
  before_action :set_customer
  before_action :set_milestone
  before_action :set_milestone_item, only: [ :update ]

  def create
    @milestone_item = @milestone.milestone_items.build(milestone_item_params)
    authorize @milestone_item

    if @milestone_item.save
      redirect_to customer_milestone_path(@customer, @milestone), notice: "Milestone item added."
    else
      redirect_to customer_milestone_path(@customer, @milestone), alert: @milestone_item.errors.full_messages.to_sentence
    end
  end

  def update
    authorize @milestone_item

    if @milestone_item.update(milestone_item_params)
      redirect_to customer_milestone_path(@customer, @milestone), notice: "Milestone item updated."
    else
      redirect_to customer_milestone_path(@customer, @milestone), alert: @milestone_item.errors.full_messages.to_sentence
    end
  end

  private

  def set_customer
    @customer = policy_scope(Customer).find(params[:customer_id])
  end

  def set_milestone
    @milestone = @customer.milestones.find(params[:milestone_id])
  end

  def set_milestone_item
    @milestone_item = @milestone.milestone_items.find(params[:id])
  end

  def milestone_item_params
    params.require(:milestone_item).permit(:description, :amount, :due_date, :position)
  end
end
