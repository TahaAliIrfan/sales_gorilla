class CustomersController < ApplicationController
  layout 'dashboard'
  before_action :require_login
  before_action :set_customer, only: [:show, :edit, :update, :destroy, :update_status, :analyze_phone]
  after_action :verify_authorized, except: :index
  after_action :verify_policy_scoped, only: :index

  def index
    @users = User.all if current_user&.admin?
    
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
    if params[:user_id].present? && current_user&.admin?
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
      render :new, status: :unprocessable_entity
      return
    end

    begin
      # Use save! to raise an exception on validation failure
      @customer.save!
      redirect_to @customer, notice: 'Customer was successfully created.'
    rescue ActiveRecord::RecordInvalid
      render :new, status: :unprocessable_entity
    rescue => e
      @customer.errors.add(:base, "An unexpected error occurred: #{e.message}")
      render :new, status: :unprocessable_entity
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
    
    # Assign attributes but don't save yet
    @customer.assign_attributes(customer_params)
    
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
    authorize @customer
    @customer.destroy
    redirect_to customers_path, notice: 'Customer was successfully deleted.'
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
    valid_status_types = ['call_status', 'email_status', 'whatsapp_status', 'linkedin_status']
    valid_status_values = case status_type
                          when 'call_status'
                            Customer::CALL_STATUSES.values
                          when 'email_status'
                            Customer::EMAIL_STATUSES.values
                          when 'whatsapp_status'
                            Customer::WHATSAPP_STATUSES.values
                          when 'linkedin_status'
                            Customer::LINKEDIN_STATUSES.values
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
      :preferred_calling_time, :platform, :project_scope, :file
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
