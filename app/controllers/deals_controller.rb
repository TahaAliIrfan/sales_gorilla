class DealsController < ApplicationController
  include ActionView::Helpers::NumberHelper
  
  layout 'dashboard'
  before_action :require_login
  before_action :set_deal, only: [:show, :edit, :update, :destroy, :update_stage, :mark_as_won, :mark_as_lost, :assign_user]
  skip_before_action :verify_authenticity_token, only: [:update_stage], if: -> { request.format.json? }
  after_action :verify_authorized, except: [:index, :my_deals]
  after_action :verify_policy_scoped, only: [:index, :my_deals]

  def index
    @deals = policy_scope(Deal)
    @deal_stages = DealStage.all
  end

  def my_deals
    @deals = policy_scope(Deal).assigned_to(current_user)
    @deal_stages = DealStage.all
    render :index
  end

  def show
    authorize @deal
    @deal = Deal.includes(deal_activities: :user).find(params[:id])
    
    # Calculate time since last activity
    @last_activity = @deal.deal_activities.order(created_at: :desc).first
    @time_since_last_activity = @last_activity ? time_ago_in_words(@last_activity.created_at) : "never"
    
    # Get activities for this deal
    @activities = @deal.deal_activities.order(created_at: :desc)
    @recordings = @deal.deal_recordings.order(created_at: :desc)
  end

  def new
    @deal = Deal.new
    @deal.customer_id = params[:customer_id] if params[:customer_id].present?
    authorize @deal
    
    # Set default user to current user
    @deal.user_id = current_user.id
    
    # Get all customers for dropdown
    if current_user&.admin?
      @customers = Customer.all
      @users = User.all
    else
      @customers = Customer.where(user_id: current_user.id)
      @users = [current_user]
    end
    
    # Get all deal stages for dropdown
    @deal_stages = DealStage.all
    
    # If no deal stages exist, create some defaults
    if @deal_stages.empty?
      stages = ['Discovery', 'Qualification', 'Proposal', 'Negotiation', 'Closed Won', 'Closed Lost']
      stages.each_with_index do |name, index|
        DealStage.create(name: name, position: index + 1)
      end
      @deal_stages = DealStage.all
    end
  end

  def create
    @deal = Deal.new(deal_params)
    
    # Set the user_id to current user if not set
    @deal.user_id ||= current_user.id
    
    # If no deal stage is selected, use the first one
    @deal.deal_stage_id ||= DealStage.order(:position).first&.id
    
    authorize @deal
    
    # Validate required fields
    if @deal.title.blank?
      @deal.errors.add(:title, "can't be blank")
    end
    
    if @deal.customer_id.blank?
      @deal.errors.add(:customer_id, "can't be blank")
    end
    
    # Validate amount is a number
    if deal_params[:amount].present?
      begin
        # Try to parse the amount as a number
        parsed_amount = deal_params[:amount]
        if parsed_amount.is_a?(String)
          # Remove currency symbols and commas
          parsed_amount = parsed_amount.gsub(/[$,]/, '')
          # Convert to float
          parsed_amount = Float(parsed_amount)
        end
        @deal.amount = parsed_amount
      rescue ArgumentError
        @deal.errors.add(:amount, "must be a valid number")
      end
    end
    
    if @deal.errors.any?
      # Get all customers for dropdown
      if current_user&.admin?
        @customers = Customer.all
        @users = User.all
      else
        @customers = Customer.where(user_id: current_user.id)
        @users = [current_user]
      end
      
      # Get all deal stages for dropdown
      @deal_stages = DealStage.all
      
      render :new, status: :unprocessable_entity
      return
    end
    
    # Create an activity for the deal creation
    @deal.deal_activities.build(
      activity_type: 'deal_created',
      description: "Deal created with initial stage #{@deal.deal_stage&.name}",
      user_id: current_user.id
    )
    
    begin
      # Use save! to raise an exception on validation failure
      @deal.save!
      
      # Record the first stage update for the deal
      DealActivity.create!(
        deal_id: @deal.id,
        activity_type: 'stage_update',
        description: "Deal initially set to #{@deal.deal_stage.name} stage",
        user_id: current_user.id
      )
      
      redirect_to @deal, notice: 'Deal was successfully created.'
    rescue ActiveRecord::RecordInvalid
      # Get all customers for dropdown for rendering the form
      if current_user&.admin?
        @customers = Customer.all
        @users = User.all
      else
        @customers = Customer.where(user_id: current_user.id)
        @users = [current_user]
      end
      
      @deal_stages = DealStage.all
      render :new, status: :unprocessable_entity
    rescue => e
      # Log unexpected errors
      Rails.logger.error("Error creating deal: #{e.message}")
      @deal.errors.add(:base, "An unexpected error occurred: #{e.message}")
      
      # Get data for form
      if current_user&.admin?
        @customers = Customer.all
        @users = User.all
      else
        @customers = Customer.where(user_id: current_user.id)
        @users = [current_user]
      end
      
      @deal_stages = DealStage.all
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @deal
    
    # Get all customers for dropdown
    if current_user&.admin?
      @customers = Customer.all
      @users = User.all
    else
      @customers = Customer.where(user_id: current_user.id)
      @users = [current_user]
    end
    
    # Get all deal stages for dropdown
    @deal_stages = DealStage.all
  end

  def update
    authorize @deal
    
    # Handle amount processing
    if deal_params[:amount].present?
      begin
        # Try to parse the amount as a number
        parsed_amount = deal_params[:amount]
        if parsed_amount.is_a?(String)
          # Remove currency symbols and commas
          parsed_amount = parsed_amount.gsub(/[$,]/, '')
          # Convert to float
          parsed_amount = Float(parsed_amount)
        end
        params[:deal][:amount] = parsed_amount
      rescue ArgumentError
        @deal.errors.add(:amount, "must be a valid number")
      end
    end
    
    # Track changes for activity log
    changes = {}
    deal_params.each do |key, value|
      # Skip if the value didn't change
      next if @deal.send(key) == value
      
      # Record the change
      changes[key] = {
        old: @deal.send(key),
        new: value
      }
    end
    
    begin
      Deal.transaction do
        # Update the deal
        @deal.update!(deal_params)
        
        # Log changes as activities
        changes.each do |field, values|
          human_field = field.humanize
          
          # Special handling for certain fields
          case field
          when 'deal_stage_id'
            old_stage = DealStage.find_by(id: values[:old])&.name || 'Unknown'
            new_stage = DealStage.find_by(id: values[:new])&.name || 'Unknown'
            description = "Deal stage changed from #{old_stage} to #{new_stage}"
            activity_type = 'stage_update'
          when 'user_id'
            old_user = User.find_by(id: values[:old])&.name || 'Unknown'
            new_user = User.find_by(id: values[:new])&.name || 'Unknown'
            description = "Deal assigned from #{old_user} to #{new_user}"
            activity_type = 'user_assignment'
          when 'amount'
            old_amount = number_to_currency(values[:old]) rescue values[:old]
            new_amount = number_to_currency(values[:new]) rescue values[:new]
            description = "Deal amount changed from #{old_amount} to #{new_amount}"
            activity_type = 'field_update'
          when 'expected_close_date'
            old_date = values[:old]&.to_date&.to_s || 'None'
            new_date = values[:new]&.to_date&.to_s || 'None'
            description = "Expected close date changed from #{old_date} to #{new_date}"
            activity_type = 'field_update'
          else
            description = "#{human_field} changed from \"#{values[:old]}\" to \"#{values[:new]}\""
            activity_type = 'field_update'
          end
          
          # Create activity record
          DealActivity.create!(
            deal_id: @deal.id,
            activity_type: activity_type,
            description: description,
            user_id: current_user.id
          )
        end
      end
      
      redirect_to @deal, notice: 'Deal was successfully updated.'
    rescue ActiveRecord::RecordInvalid
      # Get data for form
      if current_user&.admin?
        @customers = Customer.all
        @users = User.all
      else
        @customers = Customer.where(user_id: current_user.id)
        @users = [current_user]
      end
      
      @deal_stages = DealStage.all
      render :edit, status: :unprocessable_entity
    rescue => e
      Rails.logger.error("Error updating deal: #{e.message}")
      @deal.errors.add(:base, "An unexpected error occurred: #{e.message}")
      
      # Get data for form
      if current_user&.admin?
        @customers = Customer.all
        @users = User.all
      else
        @customers = Customer.where(user_id: current_user.id)
        @users = [current_user]
      end
      
      @deal_stages = DealStage.all
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @deal
    
    begin
      @deal.destroy!
      redirect_to deals_url, notice: 'Deal was successfully deleted.'
    rescue => e
      redirect_to deals_url, alert: "Could not delete the deal: #{e.message}"
    end
  end

  def update_stage
    authorize @deal
    previous_stage = @deal.deal_stage
    new_stage = DealStage.find(params[:deal_stage_id])
    
    if @deal.update(deal_stage_id: params[:deal_stage_id])
      # Create activity
      DealActivity.create(
        deal_id: @deal.id,
        activity_type: 'stage_update',
        description: "Deal moved from #{previous_stage.name} to #{new_stage.name}",
        user_id: current_user.id
      )
      
      render json: { success: true }
    else
      render json: { success: false, errors: @deal.errors.full_messages }, status: :unprocessable_entity
    end
  end

  def assign_user
    authorize @deal
    previous_user = @deal.user
    new_user = User.find(params[:user_id])
    
    if @deal.update(user_id: params[:user_id])
      # Create activity
      DealActivity.create(
        deal_id: @deal.id,
        activity_type: 'user_assignment',
        description: "Deal assigned from #{previous_user&.name || 'Unassigned'} to #{new_user.name}",
        user_id: current_user.id
      )
      
      redirect_to @deal, notice: 'Deal was successfully assigned.'
    else
      redirect_to @deal, alert: 'Failed to assign deal.'
    end
  end

  def mark_as_won
    authorize @deal
    if @deal.update(status: 'won')
      # Create activity
      DealActivity.create(
        deal_id: @deal.id,
        activity_type: 'status_update',
        description: "Deal marked as Won",
        user_id: current_user.id
      )
      redirect_to @deal, notice: 'Deal was marked as Won.'
    else
      redirect_to @deal, alert: 'Failed to update deal status.'
    end
  end

  def mark_as_lost
    authorize @deal
    if @deal.update(status: 'lost')
      # Create activity
      DealActivity.create(
        deal_id: @deal.id,
        activity_type: 'status_update',
        description: "Deal marked as Lost",
        user_id: current_user.id
      )
      redirect_to @deal, notice: 'Deal was marked as Lost.'
    else
      redirect_to @deal, alert: 'Failed to update deal status.'
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
