class CustomersController < ApplicationController
  layout 'dashboard'
  before_action :require_login
  before_action :set_customer, only: [:show, :edit, :update, :destroy, :update_status, :analyze_phone, :ai_call, :calculate_lead_score]
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  def index
    @users = if current_user&.admin?
      User.all
    elsif current_user&.manager?
      # Managers can assign to themselves and their associates
      [current_user] + current_user.associates
    end
    
    # Check if this is an AJAX request for client-side filtering
    if request.xhr?
      @customers = policy_scope(Customer).includes(:user, :deals)
      
      render json: @customers.as_json(
        include: { 
          user: { only: [:id, :name] },
          deals: { only: [:id, :status] }
        },
        methods: [:active_deals_count]
      )
      return
    end
    
    # For regular requests, apply server-side filtering
    @customers = policy_scope(Customer)
    
    # Apply filters using scopes
    if params[:user_id].present? && (current_user&.admin? || current_user&.manager?)
      if params[:user_id] == 'unassigned'
        @customers = @customers.where(user_id: nil)
      else
        @customers = @customers.assigned_to(params[:user_id])
      end
    end
    @customers = @customers.search(params[:search])
    
    # Filter by status if provided (for all users, not just admins)
    if params[:status].present?
      Rails.logger.debug("Filtering by status: #{params[:status]}")
      @customers = @customers.where(status: params[:status])
    end
    
    # Filter by lead source if provided
    @customers = @customers.where(lead_source: params[:lead_source]) if params[:lead_source].present?
    
    # Apply sorting - always sort by created_at since we removed the sort column
    sort_direction = %w[asc desc].include?(params[:direction]) ? params[:direction] : 'desc'
    @customers = @customers.order("created_at #{sort_direction}")
    
    # Apply pagination with 20 items per page
    @customers = @customers.page(params[:page]).per(20)
    
    # Track filter state for the view
    @filter_applied = params[:search].present? || params[:user_id].present? || 
                      params[:status].present? || params[:lead_source].present?
  end

  def show
    authorize @customer
    @deals = @customer.deals
    @activities = @customer.customer_activities.recent.limit(10)
    @recordings = @customer.recordings.recent.limit(20)
    @tasks = @customer.tasks.order(due_date: :asc)
    @emails = @customer.emails.recent.limit(5)

    if @customer.email.present?
      CustomerEmailFetchWorker.perform_async(@customer.id, current_user.id)

      Rails.cache.write("customer_#{@customer.id}_email_count_before", @customer.emails.count)

      @email_fetching_active = true
    end
  end

  def new
    @customer = Customer.new
    authorize @customer
  end

  def create
    @customer = Customer.new(customer_params)

    if !current_user&.admin? || @customer.user_id.nil?
      @customer.user_id = current_user.id
    end
    
    authorize @customer

    # Validate required fields
    if @customer.name.blank?
      @customer.errors.add(:name, "can't be blank")
    end
    
    if @customer.errors.any?
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: { errors: @customer.errors }, status: :unprocessable_entity }
      end
      return
    end

    begin
      @customer.save!
      
      respond_to do |format|
        format.html { redirect_to @customer, notice: 'Customer was successfully created.' }
        format.json { 
          # Ensure we render JSON with proper headers
          response.headers['Content-Type'] = 'application/json'
          render json: { id: @customer.id, name: @customer.name, phone: @customer.phone }, status: :created 
        }
      end
    rescue ActiveRecord::RecordInvalid
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { 
          response.headers['Content-Type'] = 'application/json'
          render json: { errors: @customer.errors }, status: :unprocessable_entity 
        }
      end
    rescue => e
      @customer.errors.add(:base, "An unexpected error occurred: #{e.message}")
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json { 
          response.headers['Content-Type'] = 'application/json'
          render json: { errors: @customer.errors }, status: :unprocessable_entity 
        }
      end
    end
  end

  def edit
    authorize @customer
  end

  def update
    authorize @customer
    
    # Log the original phone number
    Rails.logger.debug("Original phone number: #{@customer.phone}")
    Rails.logger.debug("New phone number from params: #{customer_params[:phone]}")
    
    # Handle document attachments
    if params[:customer][:documents].present?
      params[:customer][:documents].each do |document|
        @customer.documents.attach(document)
      end
    end
    
    # Assign attributes but don't save yet
    @customer.assign_attributes(customer_params.except(:documents))
    
    # Log the phone number after assignment
    Rails.logger.debug("Phone number after assignment: #{@customer.phone}")

    # Validate required fields
    if @customer.name.blank?
      @customer.errors.add(:name, "can't be blank")
    end
    
    if @customer.errors.any?
      render :edit, status: :unprocessable_entity
      return
    end
    
    begin
      # Use save! to raise an exception on validation failure
      @customer.save!
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
    @customer = Customer.find(params[:id])
    
    if params[:remove_document].present?
      authorize @customer, :remove_document?
      
      # Debug logging
      Rails.logger.info "Attempting to remove document with signed_id: #{params[:remove_document]}"
      Rails.logger.info "Customer has #{@customer.documents.count} documents"
      
      begin
        # Find the blob
        blob = ActiveStorage::Blob.find_signed(params[:remove_document])
        Rails.logger.info "Found blob: #{blob.id} - #{blob.filename}"
        
        # Find the attachment that uses this blob
        attachment = @customer.documents.find { |doc| doc.blob.id == blob.id }
        
        if attachment
          Rails.logger.info "Found attachment, purging..."
          attachment.purge
          redirect_to @customer, notice: 'Document was successfully removed.'
        else
          Rails.logger.error "Attachment not found for blob #{blob.id}"
          redirect_to @customer, alert: 'Document not found.'
        end
      rescue ActiveStorage::InvalidSignature => e
        Rails.logger.error "Invalid signed ID: #{e.message}"
        redirect_to @customer, alert: 'Invalid document reference.'
      rescue => e
        Rails.logger.error "Error removing document: #{e.message}"
        redirect_to @customer, alert: 'Failed to remove document.'
      end
    else
      authorize @customer, :destroy?
      @customer.destroy
      redirect_to customers_url, notice: 'Customer was successfully deleted.'
    end
  end

  def update_status
    @customer = Customer.find(params[:id])
    authorize @customer
    
    if @customer.update(status: params[:status])
      respond_to do |format|
        format.html { redirect_to @customer, notice: 'Status updated successfully.' }
        format.json { render json: { success: true } }
      end
    else
      respond_to do |format|
        format.html { redirect_to @customer, alert: 'Failed to update status.' }
        format.json { render json: { success: false, errors: @customer.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def update_communication_status
    @customer = Customer.find(params[:id])
    authorize @customer
    
    # Extract status type and value from params
    status_type = params[:status_type]
    status_value = params[:status_value]
    
    # Validate status type and value before updating
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
      respond_to do |format|
        format.html { redirect_to @customer, alert: 'Invalid status type or value' }
        format.json { render json: { success: false, error: 'Invalid status type or value' }, status: :unprocessable_entity }
      end
      return
    end
    
    if @customer.update(status_type => status_value)
      respond_to do |format|
        format.html { redirect_to @customer, notice: "#{status_type.humanize} updated successfully" }
        format.json { render json: { success: true } }
      end
    else
      respond_to do |format|
        format.html { redirect_to @customer, alert: "Failed to update #{status_type.humanize}" }
        format.json { render json: { success: false, errors: @customer.errors.full_messages }, status: :unprocessable_entity }
      end
    end
  end

  def bulk_assign
    authorize Customer
    
    if !params[:customer_ids].present? || !params[:user_id].present?
      redirect_to customers_path, alert: 'Please select customers and a user to assign.'
      return
    end
    
    # Log the raw input for debugging
    Rails.logger.info("Raw customer_ids input: #{params[:customer_ids].inspect}")
    
    # Find customers - ensure we're parsing the IDs correctly
    customer_ids = params[:customer_ids].to_s.split(',').map(&:strip).reject(&:blank?).map(&:to_i).reject(&:zero?)
    
    if customer_ids.empty?
      redirect_to customers_path, alert: 'No valid customers selected.'
      return
    end
    
    # Log for debugging
    Rails.logger.info("Processed customer IDs: #{customer_ids.inspect}")
    Rails.logger.info("Bulk assigning customers to user: #{params[:user_id]}")
    
    # Find customers
    customers = Customer.where(id: customer_ids)
    Rails.logger.info("Found #{customers.count} customers out of #{customer_ids.count} requested")
    
    # Verify all requested customers were found
    if customers.count != customer_ids.count
      missing_ids = customer_ids - customers.pluck(:id)
      Rails.logger.warn("Missing customer IDs: #{missing_ids.inspect}")
    end
    
    # Find user
    user = User.find_by(id: params[:user_id])
    
    if !user
      redirect_to customers_path, alert: 'Selected user not found.'
      return
    end
    
    # Check if current user is a manager and is trying to assign to someone other than themselves or their associates
    if current_user.manager? && !current_user.admin?
      # Get the list of valid assignees for this manager (self + associates)
      valid_assignee_ids = [current_user.id] + current_user.associates.pluck(:id)
      
      # Check if the target user is in the valid assignees list
      unless valid_assignee_ids.include?(user.id)
        redirect_to customers_path, alert: 'You can only assign customers to yourself or your team members.'
        return
      end
    end
    
    # Check user
    Rails.logger.info("Assigning to user: #{user.name} (ID: #{user.id})")
    
    # Assign customers to user
    success_count = 0
    failed_ids = []
    
    customers.each do |customer|
      begin
        Rails.logger.info("Assigning customer #{customer.id}: #{customer.name} to user #{user.id}")
        if customer.update(user_id: user.id)
          success_count += 1
          Rails.logger.info("Successfully assigned customer #{customer.id}")
        else
          failed_ids << customer.id
          Rails.logger.error("Failed to assign customer #{customer.id}: #{customer.errors.full_messages.join(', ')}")
        end
      rescue => e
        failed_ids << customer.id
        Rails.logger.error("Exception assigning customer #{customer.id}: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
      end
    end
    
    Rails.logger.info("Bulk assign complete. Success: #{success_count}, Failed: #{failed_ids.count}")
    
    if success_count == customers.count
      redirect_to customers_path, notice: "Successfully assigned #{success_count} #{'customer'.pluralize(success_count)} to #{user.name}."
    elsif success_count > 0
      redirect_to customers_path, notice: "Partially successful: Assigned #{success_count} of #{customers.count} customers to #{user.name}."
    else
      redirect_to customers_path, alert: 'Failed to assign customers.'
    end
  end

  def bulk_status_change
    authorize Customer
    
    if !params[:customer_ids].present? || !params[:status].present?
      redirect_to customers_path, alert: 'Please select customers and a status to change.'
      return
    end
    
    # Find customers - ensure we're parsing the IDs correctly
    customer_ids = params[:customer_ids].to_s.split(',').map(&:strip).reject(&:blank?).map(&:to_i).reject(&:zero?)
    
    if customer_ids.empty?
      redirect_to customers_path, alert: 'No valid customers selected.'
      return
    end
    
    # Validate status
    unless Customer::STATUSES.values.include?(params[:status])
      redirect_to customers_path, alert: 'Invalid status selected.'
      return
    end
    
    # Find customers
    customers = Customer.where(id: customer_ids)
    
    if customers.empty?
      redirect_to customers_path, alert: 'No customers found with the selected IDs.'
      return
    end
    
    # Update status for all customers
    success_count = 0
    failed_ids = []
    
    customers.each do |customer|
      begin
        if customer.update(status: params[:status])
          success_count += 1
        else
          failed_ids << customer.id
        end
      rescue => e
        failed_ids << customer.id
        Rails.logger.error("Exception updating customer #{customer.id} status: #{e.message}")
      end
    end
    
    if success_count == customers.count
      redirect_to customers_path, notice: "Successfully updated status to '#{params[:status]}' for #{success_count} #{'customer'.pluralize(success_count)}."
    elsif success_count > 0
      redirect_to customers_path, notice: "Partially successful: Updated #{success_count} of #{customers.count} customers to '#{params[:status]}'."
    else
      redirect_to customers_path, alert: 'Failed to update customer statuses.'
    end
  end

  def whatsapp_messages
    @customer = Customer.find(params[:id])
    authorize @customer

    # Set cache control headers to prevent caching
    response.headers["Cache-Control"] = "no-cache, no-store, max-age=0, must-revalidate"
    response.headers["Pragma"] = "no-cache"
    response.headers["Expires"] = "Fri, 01 Jan 1990 00:00:00 GMT"

    if @customer.whatsapp_chat_id.blank?
      render json: { success: false, error: "No WhatsApp chat ID available for this customer" }
      return
    end
    
    # Check if we should force refresh from API
    force_refresh = params[:force_refresh].present? && params[:force_refresh] == 'true'
    # Check if this is an auto-refresh request
    is_auto_refresh = params[:auto_refresh].present? && params[:auto_refresh] == 'true'

    # For auto-refresh or manual refresh, always fetch from API
    if force_refresh || is_auto_refresh
      Rails.logger.info("Fetching WhatsApp messages from API for customer #{@customer.id} (#{force_refresh ? 'manual refresh' : 'auto-refresh'})")
      messages = @customer.fetch_and_store_whatsapp_messages
    else
      # For initial load, try from DB first
      Rails.logger.info("Trying to fetch WhatsApp messages from DB for customer #{@customer.id}")
      messages = @customer.get_whatsapp_messages(force_refresh: false)
      
      # If no messages in DB, fetch from API
      if messages.empty?
        Rails.logger.info("No messages in DB, fetching from API for customer #{@customer.id}")
        messages = @customer.fetch_and_store_whatsapp_messages
      end
    end
    
    if messages.empty?
      render json: { success: true, data: { data: [] }, message: "No messages found" }
      return
    end
    
    # Convert DB messages to API format for the UI
    formatted_messages = messages.map do |msg|
      {
        message: {
          _data: msg.metadata,
          body: msg.body
        }
      }
    end
    
    Rails.logger.info("Returning #{formatted_messages.length} WhatsApp messages for customer #{@customer.id}")
    render json: { success: true, data: { data: formatted_messages } }
  end

  def send_whatsapp_text
    @customer = Customer.find(params[:id])
    authorize @customer

    if @customer.whatsapp_chat_id.blank?
      render json: { success: false, error: "No WhatsApp chat ID available for this customer" }
      return
    end
    
    message_text = params[:message]
    
    if message_text.blank?
      render json: { success: false, error: "Message text is required" }
      return
    end
    
    # Initialize the WhatsApp API service
    api_service = Whatsapp::ApiService.new
    
    # Send the message
    response = api_service.send_text_message(@customer.whatsapp_chat_id, message_text)
    
    if response[:success]
      # Save the message to the database
      message_data = response[:data]
      
      # Create a format similar to what the API returns for received messages
      # So we can use the import_from_api method
      formatted_data = {
        message: {
          _data: {
            id: { _serialized: message_data[:id] },
            t: Time.current.to_i,
            fromMe: true,
            status: 'sent',
            type: 'text'
          },
          body: message_text
        }
      }
      
      # Import the message to the database
      Rails.logger.info("Storing sent WhatsApp text message to database: #{message_text}")
      WhatsappMessage.import_from_api(@customer, formatted_data)
      
      render json: { 
        success: true, 
        message: "Message sent successfully", 
        data: message_data 
      }
    else
      Rails.logger.error("Failed to send WhatsApp text message: #{response[:error]}")
      render json: { 
        success: false, 
        error: response[:error] || "Failed to send message" 
      }
    end
  end
  
  def send_whatsapp_media
    @customer = Customer.find(params[:id])
    authorize @customer

    if @customer.whatsapp_chat_id.blank?
      render json: { success: false, error: "No WhatsApp chat ID available for this customer" }
      return
    end
    
    media_url = params[:media_url]
    caption = params[:caption]
    media_type = params[:media_type] || 'image'
    
    if media_url.blank?
      render json: { success: false, error: "Media URL is required" }
      return
    end
    
    # Validate media type
    unless ['image', 'video', 'audio', 'document'].include?(media_type)
      render json: { success: false, error: "Invalid media type. Must be image, video, audio, or document" }
      return
    end
    
    # Initialize the WhatsApp API service
    api_service = Whatsapp::ApiService.new
    
    # Send the media message
    response = api_service.send_media_message(@customer.whatsapp_chat_id, media_url, caption, media_type)
    
    if response[:success]
      # Save the message to the database
      message_data = response[:data]
      
      # Create a format similar to what the API returns for received messages
      # So we can use the import_from_api method
      formatted_data = {
        message: {
          _data: {
            id: { _serialized: message_data[:id] },
            t: Time.current.to_i,
            fromMe: true,
            status: 'sent',
            type: media_type,
            caption: caption
          },
          body: caption || "Media: #{media_type}"
        }
      }
      
      # Import the message to the database
      WhatsappMessage.import_from_api(@customer, formatted_data)
      
      render json: { 
        success: true, 
        message: "Media message sent successfully", 
        data: message_data 
      }
    else
      render json: { 
        success: false, 
        error: response[:error] || "Failed to send media message" 
      }
    end
  end

  def analyze_phone
    authorize @customer
    
    if @customer.phone.blank?
      respond_to do |format|
        format.html { redirect_to @customer, alert: 'Customer does not have a phone number.' }
        format.json { render json: { success: false, error: 'Customer does not have a phone number.' }, status: :unprocessable_entity }
      end
      return
    end
    
    if @customer.analyze_phone_number
      respond_to do |format|
        format.html { redirect_to @customer, notice: 'Phone analysis has been queued.' }
        format.json { render json: { success: true } }
      end
    else
      respond_to do |format|
        format.html { redirect_to @customer, alert: 'Failed to queue phone analysis.' }
        format.json { render json: { success: false, error: 'Failed to queue phone analysis.' }, status: :unprocessable_entity }
      end
    end
  end

  def ai_call
    authorize @customer
    
    if @customer.phone.blank?
      respond_to do |format|
        format.html { redirect_to @customer, alert: 'Customer does not have a phone number.' }
        format.json { render json: { success: false, error: 'Customer does not have a phone number.' }, status: :unprocessable_entity }
      end
      return
    end
    
    begin
      eleven_labs_service = ElevenLabsService.new
      result = eleven_labs_service.make_outbound_call(@customer.phone)
      
      respond_to do |format|
        format.html { redirect_to @customer, notice: 'AI call has been initiated successfully.' }
        format.json { render json: { success: true, data: result } }
      end
    rescue => e
      Rails.logger.error("Failed to initiate AI call for customer #{@customer.id}: #{e.message}")
      
      respond_to do |format|
        format.html { redirect_to @customer, alert: "Failed to initiate AI call: #{e.message}" }
        format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
      end
    end
  end

  def calculate_lead_score
    authorize @customer
    
    begin
     @customer.calculate_lead_score
      
      respond_to do |format|
        format.html { redirect_to @customer, notice: 'Lead score calculated successfully.' }
        format.json { 
          render json: { 
            success: true, 
            lead_score: @customer.lead_score,
            geographic_score: @customer.geographic_score,
            description_score: @customer.description_score,
            lead_score_badge: @customer.lead_score_badge,
            lead_score_color: @customer.lead_score_color,
            updated_at: @customer.lead_score_updated_at&.strftime('%b %d, %Y at %I:%M %p')
          } 
        }
      end
    rescue => e
      Rails.logger.error("Failed to calculate lead score for customer #{@customer.id}: #{e.message}")
      
      respond_to do |format|
        format.html { redirect_to @customer, alert: "Failed to calculate lead score: #{e.message}" }
        format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
      end
    end
  end

  private

  def set_customer
    @customer = Customer.find(params[:id])
  end

  def customer_params

    # Only permit parameters that are actually in the form
    permitted_params = [
      :name, :email, :phone, :address, :company, :notes,
      :lead_source, :linkedin_url, :ccr_link, :project_estimated_cost,
      :project_type, :idea_description, :country, :status, :call_status,
      :email_status, :whatsapp_status, :linkedin_status, :upwork_profile, :exhaust_status,
      :preferred_calling_time, :platform, :project_scope, documents: []
    ]

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
