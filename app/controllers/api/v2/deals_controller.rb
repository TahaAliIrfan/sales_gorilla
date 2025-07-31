class Api::V2::DealsController < Api::V2::BaseController
  before_action :set_deal, only: [:show, :update, :destroy, :update_stage, :mark_as_won, :mark_as_lost, :assign_user]
  after_action :verify_authorized, except: [:index, :my_deals]
  after_action :verify_policy_scoped, only: [:index, :my_deals]

  def index
    @deals = policy_scope(Deal)
    
    # Get user's accessible pipelines
    @pipelines = current_user.admin? ? Pipeline.active.order(:name) : current_user.assigned_pipelines.active.order(:name)
    
    # Handle pipeline selection
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
      if current_user.admin? && (params[:pipeline_id] == "" || params[:pipeline_id].blank?)
        @deal_stages = policy_scope(DealStage)
      elsif @pipelines.count == 1
        @selected_pipeline = @pipelines.first
        @deals = @deals.by_pipeline(@selected_pipeline)
        @deal_stages = @selected_pipeline.deal_stages.active.ordered
      elsif @pipelines.count > 1
        @selected_pipeline = @pipelines.first
        @deals = @deals.by_pipeline(@selected_pipeline)
        @deal_stages = @selected_pipeline.deal_stages.active.ordered
      else
        @deals = @deals.none
        @deal_stages = DealStage.none
      end
    end
    
    apply_filters
    
    # Apply pagination
    page = params[:page] || 1
    per_page = params[:per_page] || 20
    @deals = @deals.page(page).per(per_page)
    
    render_success({
      deals: @deals.as_json(
        include: {
          customer: { only: [:id, :name, :company] },
          user: { only: [:id, :name] },
          deal_stage: { only: [:id, :name, :position] }
        }
      ),
      deal_stages: @deal_stages.as_json,
      pipelines: @pipelines.as_json,
      pagination: {
        current_page: @deals.current_page,
        total_pages: @deals.total_pages,
        total_count: @deals.total_count,
        per_page: @deals.limit_value
      }
    })
  end

  def my_deals
    @deals = policy_scope(Deal).assigned_to(current_user)
    
    # Apply same pipeline logic as index
    @pipelines = current_user.admin? ? Pipeline.active.order(:name) : current_user.assigned_pipelines.active.order(:name)
    
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
      if current_user.admin? && (params[:pipeline_id] == "" || params[:pipeline_id].blank?)
        @deal_stages = policy_scope(DealStage)
      elsif @pipelines.count == 1
        @selected_pipeline = @pipelines.first
        @deals = @deals.by_pipeline(@selected_pipeline)
        @deal_stages = @selected_pipeline.deal_stages.active.ordered
      elsif @pipelines.count > 1
        @selected_pipeline = @pipelines.first
        @deals = @deals.by_pipeline(@selected_pipeline)
        @deal_stages = @selected_pipeline.deal_stages.active.ordered
      else
        @deals = @deals.none
        @deal_stages = DealStage.none
      end
    end
    
    apply_filters
    
    # Apply pagination
    page = params[:page] || 1
    per_page = params[:per_page] || 20
    @deals = @deals.page(page).per(per_page)
    
    render_success({
      deals: @deals.as_json(
        include: {
          customer: { only: [:id, :name, :company] },
          user: { only: [:id, :name] },
          deal_stage: { only: [:id, :name, :position] }
        }
      ),
      deal_stages: @deal_stages.as_json,
      pipelines: @pipelines.as_json,
      pagination: {
        current_page: @deals.current_page,
        total_pages: @deals.total_pages,
        total_count: @deals.total_count,
        per_page: @deals.limit_value
      }
    })
  end

  def show
    authorize @deal
    @deal = Deal.includes(deal_activities: :user).find(params[:id])
    
    render_success({
      deal: @deal.as_json(
        include: {
          customer: { only: [:id, :name, :company, :email, :phone] },
          user: { only: [:id, :name] },
          deal_stage: { only: [:id, :name, :position] }
        }
      ),
      activities: @deal.deal_activities.order(created_at: :desc).as_json(include: { user: { only: [:id, :name] } }),
      recordings: @deal.deal_recordings.order(created_at: :desc)
    })
  end

  def create
    @deal = Deal.new(deal_params)
    @deal.user_id ||= current_user.id
    @deal.deal_stage_id ||= DealStage.order(:position).first&.id
    @deal.status ||= 'active'
    
    authorize @deal
    
    if @deal.save
      # Create activity for deal creation
      DealActivity.create!(
        deal_id: @deal.id,
        action: 'deal_created',
        details: "Deal created with initial stage #{@deal.deal_stage&.name}",
        user_id: current_user.id
      )
      
      render_success(
        { 
          deal: @deal.as_json(
            include: {
              customer: { only: [:id, :name, :company] },
              user: { only: [:id, :name] },
              deal_stage: { only: [:id, :name, :position] }
            }
          )
        }, 
        'Deal created successfully', 
        :created
      )
    else
      render_error('Failed to create deal', @deal.errors.full_messages, :unprocessable_entity)
    end
  end

  def update
    authorize @deal
    
    # Track changes for activity log
    changes = {}
    deal_params.each do |key, value|
      next if @deal.send(key) == value
      changes[key] = {
        old: @deal.send(key),
        new: value
      }
    end
    
    if @deal.update(deal_params)
      # Log changes as activities
      changes.each do |field, values|
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
        else
          details = "#{field.humanize} changed from \"#{values[:old]}\" to \"#{values[:new]}\""
          action = 'field_update'
        end
        
        DealActivity.create!(
          deal_id: @deal.id,
          action: action,
          details: details,
          user_id: current_user.id
        )
      end
      
      render_success(
        { 
          deal: @deal.as_json(
            include: {
              customer: { only: [:id, :name, :company] },
              user: { only: [:id, :name] },
              deal_stage: { only: [:id, :name, :position] }
            }
          )
        }, 
        'Deal updated successfully'
      )
    else
      render_error('Failed to update deal', @deal.errors.full_messages, :unprocessable_entity)
    end
  end

  def destroy
    authorize @deal
    
    if @deal.destroy
      render_success(nil, 'Deal deleted successfully')
    else
      render_error('Failed to delete deal')
    end
  end

  def update_stage
    authorize @deal
    previous_stage = @deal.deal_stage
    new_stage = DealStage.find(params[:deal_stage_id])
    
    if @deal.update(deal_stage_id: params[:deal_stage_id])
      DealActivity.create(
        deal_id: @deal.id,
        action: 'stage_update',
        details: "Deal moved from #{previous_stage.name} to #{new_stage.name}",
        user_id: current_user.id
      )
      
      render_success({ deal: @deal }, 'Deal stage updated successfully')
    else
      render_error('Failed to update deal stage', @deal.errors.full_messages, :unprocessable_entity)
    end
  end

  def assign_user
    authorize @deal
    previous_user = @deal.user
    new_user = User.find(params[:user_id])
    
    if @deal.update(user_id: params[:user_id])
      DealActivity.create(
        deal_id: @deal.id,
        action: 'user_assignment',
        details: "Deal assigned from #{previous_user&.name || 'Unassigned'} to #{new_user.name}",
        user_id: current_user.id
      )
      
      render_success({ deal: @deal }, 'Deal assigned successfully')
    else
      render_error('Failed to assign deal', @deal.errors.full_messages, :unprocessable_entity)
    end
  end

  def mark_as_won
    authorize @deal
    closing_date_value = params[:closing_date].present? ? Date.parse(params[:closing_date]) : Date.today
    
    if @deal.update(status: 'won', closing_date: closing_date_value)
      DealActivity.create(
        deal_id: @deal.id,
        action: 'status_update',
        details: "Deal marked as Won with closing date #{closing_date_value.strftime('%b %d, %Y')}",
        user_id: current_user.id
      )
      render_success({ deal: @deal }, 'Deal marked as Won')
    else
      render_error('Failed to mark deal as won', @deal.errors.full_messages, :unprocessable_entity)
    end
  end

  def mark_as_lost
    authorize @deal
    closing_date_value = params[:closing_date].present? ? Date.parse(params[:closing_date]) : Date.today
    
    if @deal.update(status: 'lost', closing_date: closing_date_value)
      DealActivity.create(
        deal_id: @deal.id,
        action: 'status_update',
        details: "Deal marked as Lost with closing date #{closing_date_value.strftime('%b %d, %Y')}",
        user_id: current_user.id
      )
      render_success({ deal: @deal }, 'Deal marked as Lost')
    else
      render_error('Failed to mark deal as lost', @deal.errors.full_messages, :unprocessable_entity)
    end
  end

  private

  def set_deal
    @deal = Deal.find(params[:id])
  end

  def deal_params
    params.require(:deal).permit(:title, :description, :amount, :customer_id, :user_id, :deal_stage_id, :expected_close_date, :status, :created_at, :closing_date)
  end

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
      
      if start_date && end_date
        if params[:status].present? && %w[won lost].include?(params[:status])
          @deals = @deals.where(closing_date: start_date..end_date)
        else
          @deals = @deals.where("(status = 'active') OR (status IN ('won', 'lost') AND closing_date BETWEEN ? AND ?)", 
                               start_date, end_date)
        end
      end
    end
  end
end