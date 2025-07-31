class Api::V2::CustomersController < Api::V2::BaseController
  before_action :set_customer, only: [:show, :update, :destroy, :update_status, :update_communication_status, :analyze_phone, :whatsapp_messages, :send_whatsapp_text, :send_whatsapp_media]
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  def index
    @customers = policy_scope(Customer).includes(:user, :deals)
    
    # Apply filters
    @customers = @customers.assigned_to(params[:user_id]) if params[:user_id].present? && params[:user_id] != 'unassigned'
    @customers = @customers.where(user_id: nil) if params[:user_id] == 'unassigned'
    @customers = @customers.search(params[:search]) if params[:search].present?
    @customers = @customers.where(status: params[:status]) if params[:status].present?
    @customers = @customers.where(lead_source: params[:lead_source]) if params[:lead_source].present?
    
    # Apply sorting
    sort_direction = %w[asc desc].include?(params[:direction]) ? params[:direction] : 'desc'
    @customers = @customers.order("created_at #{sort_direction}")
    
    # Apply pagination
    page = params[:page] || 1
    per_page = params[:per_page] || 20
    @customers = @customers.page(page).per(per_page)
    
    render_success({
      customers: @customers.as_json(
        include: { 
          user: { only: [:id, :name] },
          deals: { only: [:id, :status] }
        },
        methods: [:active_deals_count]
      ),
      pagination: {
        current_page: @customers.current_page,
        total_pages: @customers.total_pages,
        total_count: @customers.total_count,
        per_page: @customers.limit_value
      }
    })
  end

  def show
    authorize @customer
    render_success({
      customer: @customer.as_json(
        include: {
          user: { only: [:id, :name] },
          deals: { only: [:id, :title, :status, :amount] },
          tasks: { only: [:id, :title, :status, :due_date] }
        }
      ),
      activities: @customer.customer_activities.recent.limit(10),
      recordings: @customer.recordings.recent.limit(20),
      emails: @customer.emails.recent.limit(5)
    })
  end

  def create
    @customer = Customer.new(customer_params)
    
    if !current_user&.admin? || @customer.user_id.nil?
      @customer.user_id = current_user.id
    end
    
    authorize @customer
    
    if @customer.save
      render_success(
        { 
          customer: @customer.as_json(include: { user: { only: [:id, :name] } })
        }, 
        'Customer created successfully', 
        :created
      )
    else
      render_error('Failed to create customer', @customer.errors.full_messages, :unprocessable_entity)
    end
  end

  def update
    authorize @customer
    
    # Handle document attachments
    if params[:customer][:documents].present?
      params[:customer][:documents].each do |document|
        @customer.documents.attach(document)
      end
    end
    
    if @customer.update(customer_params.except(:documents))
      render_success(
        { 
          customer: @customer.as_json(include: { user: { only: [:id, :name] } })
        }, 
        'Customer updated successfully'
      )
    else
      render_error('Failed to update customer', @customer.errors.full_messages, :unprocessable_entity)
    end
  end

  def destroy
    authorize @customer, :destroy?
    
    if @customer.destroy
      render_success(nil, 'Customer deleted successfully')
    else
      render_error('Failed to delete customer')
    end
  end

  def update_status
    authorize @customer
    
    if @customer.update(status: params[:status])
      render_success({ customer: @customer }, 'Status updated successfully')
    else
      render_error('Failed to update status', @customer.errors.full_messages, :unprocessable_entity)
    end
  end

  def update_communication_status
    authorize @customer
    
    status_type = params[:status_type]
    status_value = params[:status_value]
    
    valid_status_types = ['call_status', 'email_status', 'whatsapp_status', 'linkedin_status', 'customer_type']
    valid_status_values = case status_type
                          when 'call_status'
                            Customer::CALL_STATUSES.values
                          when 'email_status'
                            Customer::EMAIL_STATUSES.values
                          when 'whatsapp_status'
                            Customer::WHATSAPP_STATUSES.values
                          when 'linkedin_status'
                            Customer::LINKEDIN_STATUSES.values
                          when 'customer_type'
                            Customer::CUSTOMER_TYPES.values
                          else
                            []
                          end
    
    unless valid_status_types.include?(status_type) && valid_status_values.include?(status_value)
      render_error('Invalid status type or value', nil, :unprocessable_entity)
      return
    end
    
    if @customer.update(status_type => status_value)
      render_success({ customer: @customer }, "#{status_type.humanize} updated successfully")
    else
      render_error("Failed to update #{status_type.humanize}", @customer.errors.full_messages, :unprocessable_entity)
    end
  end

  def bulk_assign
    authorize Customer
    
    customer_ids = params[:customer_ids].to_s.split(',').map(&:strip).reject(&:blank?).map(&:to_i).reject(&:zero?)
    user = User.find_by(id: params[:user_id])
    
    if customer_ids.empty? || !user
      render_error('Invalid customer IDs or user ID')
      return
    end
    
    customers = Customer.where(id: customer_ids)
    success_count = 0
    
    customers.each do |customer|
      success_count += 1 if customer.update(user_id: user.id)
    end
    
    render_success(
      { success_count: success_count, total_count: customers.count },
      "Successfully assigned #{success_count} customers to #{user.name}"
    )
  end

  def bulk_status_change
    authorize Customer
    
    customer_ids = params[:customer_ids].to_s.split(',').map(&:strip).reject(&:blank?).map(&:to_i).reject(&:zero?)
    
    if customer_ids.empty? || !Customer::STATUSES.values.include?(params[:status])
      render_error('Invalid customer IDs or status')
      return
    end
    
    customers = Customer.where(id: customer_ids)
    success_count = 0
    
    customers.each do |customer|
      success_count += 1 if customer.update(status: params[:status])
    end
    
    render_success(
      { success_count: success_count, total_count: customers.count },
      "Successfully updated #{success_count} customers to '#{params[:status]}'"
    )
  end

  def whatsapp_messages
    authorize @customer
    
    if @customer.whatsapp_chat_id.blank?
      render_error("No WhatsApp chat ID available for this customer")
      return
    end
    
    force_refresh = params[:force_refresh] == 'true'
    is_auto_refresh = params[:auto_refresh] == 'true'
    
    if force_refresh || is_auto_refresh
      messages = @customer.fetch_and_store_whatsapp_messages
    else
      messages = @customer.get_whatsapp_messages(force_refresh: false)
      messages = @customer.fetch_and_store_whatsapp_messages if messages.empty?
    end
    
    formatted_messages = messages.map do |msg|
      {
        message: {
          _data: msg.metadata,
          body: msg.body
        }
      }
    end
    
    render_success({ messages: formatted_messages })
  end

  def send_whatsapp_text
    authorize @customer
    
    if @customer.whatsapp_chat_id.blank?
      render_error("No WhatsApp chat ID available for this customer")
      return
    end
    
    if params[:message].blank?
      render_error("Message text is required")
      return
    end
    
    api_service = Whatsapp::ApiService.new
    response = api_service.send_text_message(@customer.whatsapp_chat_id, params[:message])
    
    if response[:success]
      render_success(response[:data], "Message sent successfully")
    else
      render_error(response[:error] || "Failed to send message")
    end
  end

  def send_whatsapp_media
    authorize @customer
    
    if @customer.whatsapp_chat_id.blank?
      render_error("No WhatsApp chat ID available for this customer")
      return
    end
    
    if params[:media_url].blank?
      render_error("Media URL is required")
      return
    end
    
    media_type = params[:media_type] || 'image'
    unless ['image', 'video', 'audio', 'document'].include?(media_type)
      render_error("Invalid media type. Must be image, video, audio, or document")
      return
    end
    
    api_service = Whatsapp::ApiService.new
    response = api_service.send_media_message(@customer.whatsapp_chat_id, params[:media_url], params[:caption], media_type)
    
    if response[:success]
      render_success(response[:data], "Media message sent successfully")
    else
      render_error(response[:error] || "Failed to send media message")
    end
  end

  def analyze_phone
    authorize @customer
    
    if @customer.phone.blank?
      render_error('Customer does not have a phone number', nil, :unprocessable_entity)
      return
    end
    
    if @customer.analyze_phone_number
      render_success(nil, 'Phone analysis has been queued')
    else
      render_error('Failed to queue phone analysis', nil, :unprocessable_entity)
    end
  end

  def recordings
    authorize @customer
    
    recordings = @customer.recordings.includes(:user)
    
    # Apply pagination
    page = params[:page] || 1
    per_page = params[:per_page] || 20
    recordings = recordings.page(page).per(per_page)
    
    render_success({
      recordings: recordings.as_json(
        include: {
          user: { only: [:id, :name] }
        }
      ),
      pagination: {
        current_page: recordings.current_page,
        total_pages: recordings.total_pages,
        total_count: recordings.total_count,
        per_page: recordings.limit_value
      }
    })
  end

  private

  def set_customer
    @customer = Customer.find(params[:id])
  end

  def customer_params
    permitted_params = [
      :name, :email, :phone, :address, :company, :notes,
      :lead_source, :linkedin_url, :ccr_link, :project_estimated_cost,
      :project_type, :idea_description, :country, :status, :call_status,
      :email_status, :whatsapp_status, :linkedin_status, :upwork_profile, :exhaust_status,
      :preferred_calling_time, :platform, :project_scope, documents: []
    ]

    if current_user&.admin?
      permitted_params << :user_id
    end

    params.require(:customer).permit(permitted_params)
  end
end