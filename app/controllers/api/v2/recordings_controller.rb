class Api::V2::RecordingsController < Api::V2::BaseController
  before_action :set_recording, only: [:show, :update, :destroy]
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  def index
    @recordings = policy_scope(Recording)
    
    # Apply filters
    @recordings = @recordings.where(customer_id: params[:customer_id]) if params[:customer_id].present?
    @recordings = @recordings.where(user_id: params[:user_id]) if params[:user_id].present?
    
    # Date filters
    if params[:created_from].present?
      @recordings = @recordings.where('created_at >= ?', Date.parse(params[:created_from]))
    end
    
    if params[:created_to].present?
      @recordings = @recordings.where('created_at <= ?', Date.parse(params[:created_to]))
    end
    
    # Search
    if params[:search].present?
      @recordings = @recordings.joins(:customer).where(
        'customers.name ILIKE ? OR recordings.transcript ILIKE ?', 
        "%#{params[:search]}%", 
        "%#{params[:search]}%"
      )
    end
    
    # Sorting
    sort_field = params[:sort] || 'created_at'
    sort_direction = %w[asc desc].include?(params[:direction]) ? params[:direction] : 'desc'
    @recordings = @recordings.order("#{sort_field} #{sort_direction}")
    
    # Pagination
    page = params[:page] || 1
    per_page = params[:per_page] || 20
    @recordings = @recordings.page(page).per(per_page)
    
    render_success({
      recordings: @recordings.map do |recording|
        recording.as_json(
          include: {
            customer: { only: [:id, :name, :company] },
            user: { only: [:id, :name] }
          }
        ).merge({
          'url' => recording.audio_file.attached? ? recording.audio_file.url : nil,
        })
      end,
      pagination: {
        current_page: @recordings.current_page,
        total_pages: @recordings.total_pages,
        total_count: @recordings.total_count,
        per_page: @recordings.limit_value
      }
    })
  end

  def show
    authorize @recording
    
    # Get the latest AI analysis
    latest_analysis = @recording.latest_ai_analysis
    
    render_success({
      recording: @recording.as_json(
        include: {
          customer: { 
            only: [:id, :name, :company, :email, :phone, :linkedin_url, :address, :country_code, :project_type, :status, :call_status, :email_status, :whatsapp_status]
          },
          user: { only: [:id, :name, :email] }
        }
      ).merge({ 'url' => @recording.audio_file.attached? ? @recording.audio_file.url : nil,
        'transcription' => @recording.transcription,
        'transcription_status' => @recording.transcription_status,
        'transcribed' => @recording.transcribed?,
        'customer_tasks' => @recording.customer.tasks.map do |task|
          {
            'id' => task.id,
            'title' => task.title,
            'status' => task.status,
            'priority' => task.priority,
            'due_date' => task.due_date
          }
        end,
        'customer_deals' => @recording.customer.deals.map do |deal|
          {
            'id' => deal.id,
            'title' => deal.title,
            'amount' => deal.amount,
            'status' => deal.status,
            'expected_close_date' => deal.expected_close_date
          }
        end,
        'ai_analysis' => latest_analysis ? {
          'id' => latest_analysis.id,
          'summary' => latest_analysis.summary,
          'interest_score' => latest_analysis.interest_score,
          'improvement_points' => latest_analysis.improvement_points,
          'next_steps' => latest_analysis.next_steps,
          'followup_message' => latest_analysis.followup_message,
          'followup_email' => latest_analysis.followup_email,
          'created_at' => latest_analysis.created_at
        } : nil,
        'all_ai_analyses' => @recording.ai_analyses.order(created_at: :desc).map do |analysis|
          {
            'id' => analysis.id,
            'summary' => analysis.summary,
            'interest_score' => analysis.interest_score,
            'improvement_points' => analysis.improvement_points,
            'next_steps' => analysis.next_steps,
            'followup_message' => analysis.followup_message,
            'followup_email' => analysis.followup_email,
            'created_at' => analysis.created_at
          }
        end
      })
    })
  end

  def create
    @recording = Recording.new(recording_params)
    @recording.user_id ||= current_user.id
    
    authorize @recording
    
    if @recording.save
      render_success(
        { 
          recording: @recording.as_json(
            include: {
              customer: { only: [:id, :name, :company] },
              user: { only: [:id, :name] }
            }
          )
        }, 
        'Recording created successfully', 
        :created
      )
    else
      render_error('Failed to create recording', @recording.errors.full_messages, :unprocessable_entity)
    end
  end

  def update
    authorize @recording
    
    if @recording.update(recording_params)
      render_success(
        { 
          recording: @recording.as_json(
            include: {
              customer: { only: [:id, :name, :company] },
              user: { only: [:id, :name] }
            }
          )
        }, 
        'Recording updated successfully'
      )
    else
      render_error('Failed to update recording', @recording.errors.full_messages, :unprocessable_entity)
    end
  end

  def destroy
    authorize @recording
    
    if @recording.destroy
      render_success(nil, 'Recording deleted successfully')
    else
      render_error('Failed to delete recording')
    end
  end

  private

  def set_recording
    @recording = Recording.find(params[:id])
  end

  def recording_params
    params.require(:recording).permit(:customer_id, :user_id, :duration, :s3_url, :transcript, :recording_sid, :call_sid)
  end
end