class DealsController < ApplicationController
  include ActionView::Helpers::NumberHelper
  
  layout 'dashboard'
  before_action :require_login
  before_action :set_deal, only: [:show, :edit, :update, :destroy, :update_stage, :mark_as_won, :mark_as_lost, :assign_user]
  skip_before_action :verify_authenticity_token, only: [:update_stage], if: -> { request.format.json? }

  def index
    @deals = Deal.all
    @deal_stages = DealStage.all
  end

  def my_deals
    @deals = Deal.assigned_to(current_user)
    @deal_stages = DealStage.all
    render :index
  end

  def show
    @deal = Deal.includes(deal_activities: :user).find(params[:id])
  end

  def new
    @deal = Deal.new
    
    # Set the initial deal stage if provided
    if params[:stage_id].present?
      @deal.deal_stage_id = params[:stage_id]
    end
    
    # Set the initial customer if provided
    if params[:customer_id].present?
      @deal.customer_id = params[:customer_id]
    end
    
    @customers = Customer.all
    @users = User.all
    @deal_stages = DealStage.all
  end

  def create
    @deal = Deal.new(deal_params)
    @deal.status = 'active' unless @deal.status.present?

    if @deal.save
      @deal.log_activity(current_user, 'created', "Deal '#{@deal.title}' was created")
      redirect_to @deal, notice: 'Deal was successfully created.'
    else
      @customers = Customer.all
      @users = User.all
      @deal_stages = DealStage.all
      render :new
    end
  end

  def edit
    @customers = Customer.all
    @users = User.all
    @deal_stages = DealStage.all
  end

  def update
    old_attributes = @deal.attributes
    
    if @deal.update(deal_params)
      # Log changes
      changes = []
      
      if old_attributes['title'] != @deal.title
        changes << "Title changed from '#{old_attributes['title']}' to '#{@deal.title}'"
      end
      
      if old_attributes['amount'].to_f != @deal.amount.to_f
        changes << "Amount changed from '$#{old_attributes['amount']}' to '$#{@deal.amount}'"
      end
      
      if old_attributes['customer_id'] != @deal.customer_id
        old_customer = Customer.find_by(id: old_attributes['customer_id'])
        new_customer = @deal.customer
        old_name = old_customer ? old_customer.name : 'None'
        new_name = new_customer ? new_customer.name : 'None'
        changes << "Customer changed from '#{old_name}' to '#{new_name}'"
      end
      
      if old_attributes['expected_close_date'] != @deal.expected_close_date
        old_date = old_attributes['expected_close_date'] ? old_attributes['expected_close_date'].to_date.strftime("%B %d, %Y") : 'None'
        new_date = @deal.expected_close_date ? @deal.expected_close_date.strftime("%B %d, %Y") : 'None'
        changes << "Expected close date changed from '#{old_date}' to '#{new_date}'"
      end
      
      if old_attributes['description'] != @deal.description
        changes << "Description was updated"
      end
      
      if changes.any?
        @deal.log_activity(current_user, 'updated', changes.join(". "))
      end
      
      redirect_to @deal, notice: 'Deal was successfully updated.'
    else
      @customers = Customer.all
      @users = User.all
      @deal_stages = DealStage.all
      render :edit
    end
  end

  def destroy
    title = @deal.title
    @deal.log_activity(current_user, 'deleted', "Deal '#{title}' was deleted")
    @deal.destroy
    redirect_to deals_path, notice: 'Deal was successfully deleted.'
  end

  def update_stage
    previous_stage = @deal.deal_stage
    
    if @deal.update(deal_stage_id: params[:deal_stage_id])
      @deal.log_activity(current_user, 'stage_changed', "Deal moved from '#{previous_stage.name}' to '#{@deal.deal_stage.name}'")
      respond_to do |format|
        format.html { redirect_to request.referer || @deal, notice: "Deal moved from #{previous_stage.name} to #{@deal.deal_stage.name}." }
        format.json { render json: { success: true, message: "Deal moved from #{previous_stage.name} to #{@deal.deal_stage.name}." } }
      end
    else
      respond_to do |format|
        format.html { redirect_to request.referer || @deal, alert: 'Failed to update deal stage.' }
        format.json { render json: { success: false, errors: @deal.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def assign_user
    previous_user = @deal.user
    
    if params[:user_id].present? && @deal.update(user_id: params[:user_id])
      new_user = User.find(params[:user_id])
      @deal.log_activity(current_user, 'user_assigned', "Deal reassigned from '#{previous_user.name}' to '#{new_user.name}'")
      redirect_to request.referer || @deal, notice: "Deal assigned to #{new_user.name}."
    else
      redirect_to request.referer || @deal, alert: 'Failed to assign deal to user.'
    end
  end

  def mark_as_won
    if @deal.update(status: 'won')
      @deal.log_activity(current_user, 'marked_won', "Deal marked as won")
      redirect_to request.referer || @deal, notice: 'Deal was marked as won.'
    else
      redirect_to request.referer || @deal, alert: 'Failed to mark deal as won.'
    end
  end

  def mark_as_lost
    if @deal.update(status: 'lost')
      @deal.log_activity(current_user, 'marked_lost', "Deal marked as lost")
      redirect_to request.referer || @deal, notice: 'Deal was marked as lost.'
    else
      redirect_to request.referer || @deal, alert: 'Failed to mark deal as lost.'
    end
  end

  private

  def set_deal
    @deal = Deal.find(params[:id])
  end

  def deal_params
    params.require(:deal).permit(:title, :description, :amount, :customer_id, :user_id, :deal_stage_id, :expected_close_date, :status)
  end
  
  def require_login
    unless session[:user_id]
      flash[:error] = "You must be logged in to access this section"
      redirect_to root_path
    end
  end
  
  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end
end
