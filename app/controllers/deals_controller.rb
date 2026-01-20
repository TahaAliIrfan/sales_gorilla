class DealsController < ApplicationController
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::DateHelper
  
  layout 'dashboard'
  before_action :require_login
  before_action :set_deal, only: [:show, :edit, :update, :destroy, :update_stage, :mark_as_won, :mark_as_lost, :assign_user]
  skip_before_action :verify_authenticity_token, only: [:update_stage], if: -> { request.format.json? }
  after_action :verify_authorized, except: [:index, :my_deals]
  after_action :verify_policy_scoped, only: [:index, :my_deals]

  def index
    @deals = policy_scope(Deal)
    
    # Get user's accessible pipelines
    @pipelines = current_user.admin? ? Pipeline.active.order(:name) : current_user.assigned_pipelines.active.order(:name)
    @selected_pipeline = nil
    
    # Handle pipeline selection for all users (admin and non-admin)
    if params[:pipeline_id].present? && params[:pipeline_id] != ""
      @selected_pipeline = @pipelines.find_by(id: params[:pipeline_id])
      if @selected_pipeline
        @deals = @deals.by_pipeline(@selected_pipeline)
        @deal_stages = @selected_pipeline.deal_stages.active.ordered
      else
        @deals = @deals.none
        @deal_stages = DealStage.none
      end
    else
      # Default behavior based on user type and pipeline count
      if current_user.admin? && (params[:pipeline_id] == "" || params[:pipeline_id].blank?)
        # Admin with "All Pipelines" selected or no filter
        @deal_stages = policy_scope(DealStage)
        @selected_pipeline_id = ""
      elsif @pipelines.count == 1
        # User has only one pipeline
        @selected_pipeline = @pipelines.first
        @deals = @deals.by_pipeline(@selected_pipeline)
        @deal_stages = @selected_pipeline.deal_stages.active.ordered
      elsif @pipelines.count > 1
        # User has multiple pipelines - default to first one
        @selected_pipeline = @pipelines.first
        @deals = @deals.by_pipeline(@selected_pipeline)
        @deal_stages = @selected_pipeline.deal_stages.active.ordered
      else
        # No pipelines accessible
        @deals = @deals.none
        @deal_stages = DealStage.none
      end
    end
    
    # Set default filter_range to '30' (affects only won/lost deals)
    params[:filter_range] ||= '30'
    apply_filters
    @users = if current_user&.admin?
      User.all
    elsif current_user&.manager?
      [current_user] + current_user.associates
    else
      [current_user]
    end
    @filter_range = params[:filter_range] || 'all'
    
    # Set date range based on filter (for won/lost deals)
    if @filter_range != 'all'
      @custom_start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : nil
      @custom_end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : nil
      
      case @filter_range
      when '30'
        @start_date = 30.days.ago.beginning_of_day
        @end_date = Time.current.end_of_day
      when '90'
        @start_date = 90.days.ago.beginning_of_day
        @end_date = Time.current.end_of_day
      when 'custom'
        @start_date = @custom_start_date.beginning_of_day if @custom_start_date
        @end_date = @custom_end_date.end_of_day if @custom_end_date
      end
    end
  end

  def my_deals
    @deals = policy_scope(Deal).assigned_to(current_user)
    
    # Get user's accessible pipelines
    @pipelines = current_user.admin? ? Pipeline.active.order(:name) : current_user.assigned_pipelines.active.order(:name)
    @selected_pipeline = nil
    
    # Handle pipeline selection for all users (admin and non-admin)
    if params[:pipeline_id].present? && params[:pipeline_id] != ""
      @selected_pipeline = @pipelines.find_by(id: params[:pipeline_id])
      if @selected_pipeline
        @deals = @deals.by_pipeline(@selected_pipeline)
        @deal_stages = @selected_pipeline.deal_stages.active.ordered
      else
        @deals = @deals.none
        @deal_stages = DealStage.none
      end
    else
      # Default behavior based on user type and pipeline count
      if current_user.admin? && (params[:pipeline_id] == "" || params[:pipeline_id].blank?)
        # Admin with "All Pipelines" selected or no filter
        @deal_stages = policy_scope(DealStage)
        @selected_pipeline_id = ""
      elsif @pipelines.count == 1
        # User has only one pipeline
        @selected_pipeline = @pipelines.first
        @deals = @deals.by_pipeline(@selected_pipeline)
        @deal_stages = @selected_pipeline.deal_stages.active.ordered
      elsif @pipelines.count > 1
        # User has multiple pipelines - default to first one
        @selected_pipeline = @pipelines.first
        @deals = @deals.by_pipeline(@selected_pipeline)
        @deal_stages = @selected_pipeline.deal_stages.active.ordered
      else
        # No pipelines accessible
        @deals = @deals.none
        @deal_stages = DealStage.none
      end
    end
    
    # Set default filter_range to '30' (affects only won/lost deals)
    params[:filter_range] ||= '30'
    apply_filters
    @users = if current_user&.admin?
      User.all
    elsif current_user&.manager?
      [current_user] + current_user.associates
    else
      [current_user]
    end
    @filter_range = params[:filter_range] || 'all'
    
    # Set date range based on filter (for won/lost deals)
    if @filter_range != 'all'
      @custom_start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : nil
      @custom_end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : nil
      
      case @filter_range
      when '30'
        @start_date = 30.days.ago.beginning_of_day
        @end_date = Time.current.end_of_day
      when '90'
        @start_date = 90.days.ago.beginning_of_day
        @end_date = Time.current.end_of_day
      when 'custom'
        @start_date = @custom_start_date.beginning_of_day if @custom_start_date
        @end_date = @custom_end_date.end_of_day if @custom_end_date
      end
    end
    
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
    
    # Set default status to active
    @deal.status = 'active'
    
    # Get all customers for dropdown
    if current_user&.admin?
      @customers = Customer.all
      @users = User.all
    elsif current_user&.manager?
      # Managers can create deals for their own customers and their associates' customers
      associate_ids = current_user.associates.pluck(:id)
      @customers = Customer.where(user_id: [current_user.id] + associate_ids)
      @users = [current_user] + current_user.associates
    else
      @customers = Customer.where(user_id: current_user.id)
      @users = [current_user]
    end
    
    # Get deal stages for dropdown - based on user's pipeline access or selected pipeline
    if current_user&.admin? && params[:pipeline_id].present?
      @selected_pipeline = Pipeline.find(params[:pipeline_id])
      @deal_stages = @selected_pipeline.deal_stages.active.ordered
      @pipelines = Pipeline.active.order(:name)
    else
      @deal_stages = current_user.accessible_deal_stages
    end
    
    # If no deal stages exist, create some defaults (only admins can create stages)
    if @deal_stages.empty? && current_user&.admin?
      # Get or create a default pipeline first
      default_pipeline = Pipeline.find_or_create_by(name: 'Default Pipeline') do |pipeline|
        pipeline.description = 'Default sales pipeline'
        pipeline.active = true
      end
      
      # Create default stages for the pipeline if it doesn't have any
      if default_pipeline.deal_stages.empty?
        stages = ['Discovery', 'Qualification', 'Proposal', 'Negotiation', 'Closed Won', 'Closed Lost']
        stages.each_with_index do |name, index|
          default_pipeline.deal_stages.create!(
            name: name, 
            position: index + 1,
            active: true
          )
        end
      end
      
      @deal_stages = current_user.accessible_deal_stages
    end
  end

  def create
    @deal = Deal.new(deal_params)
    
    # Set the user_id to current user if not set
    @deal.user_id ||= current_user.id
    
    # If no deal stage is selected, use the first one
    @deal.deal_stage_id ||= DealStage.order(:position).first&.id
    
    # Set default status to active if none provided
    @deal.status ||= 'active'
    
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
      elsif current_user&.manager?
        # Managers can create deals for their own customers and their associates' customers
        associate_ids = current_user.associates.pluck(:id)
        @customers = Customer.where(user_id: [current_user.id] + associate_ids)
        @users = [current_user] + current_user.associates
      else
        @customers = Customer.where(user_id: current_user.id)
        @users = [current_user]
      end
      
      # Get deal stages for dropdown
      if current_user&.admin? && params[:pipeline_id].present?
        @selected_pipeline = Pipeline.find(params[:pipeline_id])
        @deal_stages = @selected_pipeline.deal_stages.active.ordered
        @pipelines = Pipeline.active.order(:name)
      else
        @deal_stages = current_user.accessible_deal_stages
      end
      
      render :new, status: :unprocessable_entity
      return
    end
    
    # Create an activity for the deal creation
    @deal.deal_activities.build(
      action: 'deal_created',
      details: "Deal created with initial stage #{@deal.deal_stage&.name}",
      user_id: current_user.id
    )
    
    begin
      # Use save! to raise an exception on validation failure
      @deal.save!
      
      # Record the first stage update for the deal
      DealActivity.create!(
        deal_id: @deal.id,
        action: 'stage_update',
        details: "Deal initially set to #{@deal.deal_stage.name} stage",
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
      
      set_deal_stages_for_form
      render :new, status: :unprocessable_entity
    rescue => e
      # Log unexpected errors
      Rails.logger.error("Error creating deal: #{e.message}")
      @deal.errors.add(:base, "An unexpected error occurred: #{e.message}")
      
      # Get data for form
      if current_user&.admin?
        @customers = Customer.all
        @users = User.all
      elsif current_user&.manager?
        # Managers can create deals for their own customers and their associates' customers
        associate_ids = current_user.associates.pluck(:id)
        @customers = Customer.where(user_id: [current_user.id] + associate_ids)
        @users = [current_user] + current_user.associates
      else
        @customers = Customer.where(user_id: current_user.id)
        @users = [current_user]
      end
      
      set_deal_stages_for_form
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @deal
    
    # Get all customers for dropdown
    if current_user&.admin?
      @customers = Customer.all
      @users = User.all
    elsif current_user&.manager?
      # Managers can edit deals with their own customers and their associates' customers
      associate_ids = current_user.associates.pluck(:id)
      @customers = Customer.where(user_id: [current_user.id] + associate_ids)
      @users = [current_user] + current_user.associates
    else
      @customers = Customer.where(user_id: current_user.id)
      @users = [current_user]
    end
    
    # Get deal stages for dropdown - based on user's pipeline access or selected pipeline
    if current_user&.admin? && params[:pipeline_id].present?
      @selected_pipeline = Pipeline.find(params[:pipeline_id])
      @deal_stages = @selected_pipeline.deal_stages.active.ordered
      @pipelines = Pipeline.active.order(:name)
    else
      @deal_stages = current_user.accessible_deal_stages
    end
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
            details = "Deal stage changed from #{old_stage} to #{new_stage}"
            action = 'stage_update'
          when 'user_id'
            old_user = User.find_by(id: values[:old])&.name || 'Unknown'
            new_user = User.find_by(id: values[:new])&.name || 'Unknown'
            details = "Deal assigned from #{old_user} to #{new_user}"
            action = 'user_assignment'
          when 'customer_id'
            old_customer = Customer.find_by(id: values[:old])&.name || 'Unknown'
            new_customer = Customer.find_by(id: values[:new])&.name || 'Unknown'
            details = "Customer changed from \"#{old_customer}\" to \"#{new_customer}\""
            action = 'field_update'
          when 'amount'
            old_amount = number_to_currency(values[:old]) rescue values[:old]
            new_amount = number_to_currency(values[:new]) rescue values[:new]
            details = "Deal amount changed from #{old_amount} to #{new_amount}"
            action = 'field_update'
          when 'expected_close_date'
            old_date = values[:old]&.to_date&.to_s || 'None'
            new_date = values[:new]&.to_date&.to_s || 'None'
            details = "Expected close date changed from #{old_date} to #{new_date}"
            action = 'field_update'
          else
            details = "#{human_field} changed from \"#{values[:old]}\" to \"#{values[:new]}\""
            action = 'field_update'
          end
          
          # Create activity record
          DealActivity.create!(
            deal_id: @deal.id,
            action: action,
            details: details,
            user_id: current_user.id
          )
        end
      end
      
      respond_to do |format|
        format.html { redirect_to @deal, notice: 'Deal was successfully updated.' }
        format.json { render json: { success: true, message: 'Deal was successfully updated.' } }
      end
    rescue ActiveRecord::RecordInvalid
      # Get data for form
      if current_user&.admin?
        @customers = Customer.all
        @users = User.all
      elsif current_user&.manager?
        # Managers can edit deals with their own customers and their associates' customers
        associate_ids = current_user.associates.pluck(:id)
        @customers = Customer.where(user_id: [current_user.id] + associate_ids)
        @users = [current_user] + current_user.associates
      else
        @customers = Customer.where(user_id: current_user.id)
        @users = [current_user]
      end
      
      set_deal_stages_for_form
      
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { success: false, error: @deal.errors.full_messages.join(', ') }, status: :unprocessable_entity }
      end
    rescue => e
      Rails.logger.error("Error updating deal: #{e.message}")
      @deal.errors.add(:base, "An unexpected error occurred: #{e.message}")
      
      # Get data for form
      if current_user&.admin?
        @customers = Customer.all
        @users = User.all
      elsif current_user&.manager?
        # Managers can edit deals with their own customers and their associates' customers
        associate_ids = current_user.associates.pluck(:id)
        @customers = Customer.where(user_id: [current_user.id] + associate_ids)
        @users = [current_user] + current_user.associates
      else
        @customers = Customer.where(user_id: current_user.id)
        @users = [current_user]
      end
      
      set_deal_stages_for_form
      
      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
      end
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
        action: 'stage_update',
        details: "Deal moved from #{previous_stage.name} to #{new_stage.name}",
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
        action: 'user_assignment',
        details: "Deal assigned from #{previous_user&.name || 'Unassigned'} to #{new_user.name}",
        user_id: current_user.id
      )
      
      redirect_to @deal, notice: 'Deal was successfully assigned.'
    else
      redirect_to @deal, alert: 'Failed to assign deal.'
    end
  end

  def mark_as_won
    authorize @deal
    closing_date_value = params[:closing_date].present? ? Date.parse(params[:closing_date]) : (Date.today)
    
    if @deal.update(status: 'won', closing_date: closing_date_value)
      # Create activity
      DealActivity.create(
        deal_id: @deal.id,
        action: 'status_update',
        details: "Deal marked as Won with closing date #{closing_date_value.strftime('%b %d, %Y')}",
        user_id: current_user.id
      )
      redirect_to @deal, notice: 'Deal was marked as Won.'
    else
      redirect_to @deal, alert: 'Failed to update deal status.'
    end
  end

  def mark_as_lost
    authorize @deal
    closing_date_value = params[:closing_date].present? ? Date.parse(params[:closing_date]) : (Date.today)
    
    if @deal.update(status: 'lost', closing_date: closing_date_value)
      # Create activity
      DealActivity.create(
        deal_id: @deal.id,
        action: 'status_update',
        details: "Deal marked as Lost with closing date #{closing_date_value.strftime('%b %d, %Y')}",
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
    params.require(:deal).permit(:title, :description, :amount, :customer_id, :user_id, :deal_stage_id, :expected_close_date, :status, :created_at, :closing_date)
  end
  
  def set_deal_stages_for_form
    # Get deal stages for dropdown - based on user's pipeline access or selected pipeline
    if current_user&.admin? && params[:pipeline_id].present?
      @selected_pipeline = Pipeline.find(params[:pipeline_id])
      @deal_stages = @selected_pipeline.deal_stages.active.ordered
      @pipelines = Pipeline.active.order(:name)
    else
      @deal_stages = current_user.accessible_deal_stages
    end
    
    # If no deal stages are accessible and user is admin, ensure there's a default pipeline
    if @deal_stages.empty? && current_user&.admin?
      # Get or create a default pipeline first
      default_pipeline = Pipeline.find_or_create_by(name: 'Default Pipeline') do |pipeline|
        pipeline.description = 'Default sales pipeline'
        pipeline.active = true
      end
      
      # Create default stages for the pipeline if it doesn't have any
      if default_pipeline.deal_stages.empty?
        stages = ['Discovery', 'Qualification', 'Proposal', 'Negotiation', 'Closed Won', 'Closed Lost']
        stages.each_with_index do |name, index|
          default_pipeline.deal_stages.create!(
            name: name, 
            position: index + 1,
            active: true
          )
        end
      end
      
      @deal_stages = current_user.accessible_deal_stages
    end
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
  
  helper_method :current_user

  def apply_filters
    # Filter by status
    if params[:status].present? && %w[active won lost].include?(params[:status])
      @deals = @deals.where(status: params[:status])
    end
    
    # Filter by deal stage
    if params[:deal_stage_id].present?
      @deals = @deals.where(deal_stage_id: params[:deal_stage_id])
    end
    
    # Filter by user
    if params[:user_id].present? && params[:user_id] != current_user.id.to_s
      @deals = @deals.where(user_id: params[:user_id])
    end
    
    # Filter by closing date (only applies to won and lost deals)
    if params[:filter_range].present? && params[:filter_range] != 'all'
      # Calculate date range
      case params[:filter_range]
      when '30'
        start_date = 30.days.ago.beginning_of_day
        end_date = Time.current.end_of_day
      when '90'
        start_date = 90.days.ago.beginning_of_day
        end_date = Time.current.end_of_day
      when 'custom'
        start_date = params[:start_date].present? ? Date.parse(params[:start_date]).beginning_of_day : nil
        end_date = params[:end_date].present? ? Date.parse(params[:end_date]).end_of_day : nil
      end
      
      # Apply filter based on closing date (only to won/lost deals)
      if start_date && end_date
        if params[:status].present? && %w[won lost].include?(params[:status])
          # If status filter is explicitly set to won or lost, apply closing date filter
          @deals = @deals.where(closing_date: start_date..end_date)
        else
          # Otherwise, filter won/lost deals by closing date but keep all active deals
          @deals = @deals.where("(status = 'active') OR (status IN ('won', 'lost') AND closing_date BETWEEN ? AND ?)", 
                               start_date, end_date)
        end
      end
    end
  end
end
