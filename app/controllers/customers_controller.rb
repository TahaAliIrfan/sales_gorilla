class CustomersController < ApplicationController
  layout :choose_layout
  before_action :require_login
  before_action :set_customer, only: [ :show, :edit, :update, :destroy, :update_status, :update_communication_status, :analyze_phone, :calculate_lead_score, :assign_to_self, :upload_documents, :mark_lead_quality, :add_note ]
  after_action :verify_authorized, except: [ :index, :export_csv ]
  after_action :verify_policy_scoped, only: [ :index, :export_csv ]

  def index
    @users = if current_user&.admin?
      User.all
    elsif current_user&.manager?
      # Managers can assign to themselves and their associates
      [ current_user ] + current_user.associates
    end

    # Check if this is an AJAX request for client-side filtering
    if request.xhr?
      @customers = policy_scope(Customer).includes(:user, :deals)

      render json: @customers.as_json(
        include: {
          user: { only: [ :id, :name ] },
          deals: { only: [ :id, :status ] }
        },
        methods: [ :active_deals_count ]
      )
      return
    end

    @customers = apply_filters(policy_scope(Customer))

    # Apply sorting
    sort_direction = %w[asc desc].include?(params[:direction]) ? params[:direction] : "desc"
    @customers = @customers.order("created_at #{sort_direction}")

    # Apply pagination with 20 items per page
    @customers = @customers.page(params[:page]).per(20)

    # Track filter state for the view
    @filter_applied = params[:search].present? || params[:user_id].present? ||
                      params[:status].present? || params[:lead_source].present? ||
                      params[:customer_type].present? || params[:start_date].present? ||
                      params[:end_date].present?
  end

  def export_csv
    authorize Customer, :export_csv?

    customers = apply_filters(policy_scope(Customer))
      .includes(:user)
      .order(created_at: :desc)

    # "Export selected" passes the chosen ids; narrow the set when present.
    if params[:ids].present?
      ids = params[:ids].to_s.split(",").map(&:strip).reject(&:blank?).map(&:to_i).reject(&:zero?)
      customers = customers.where(id: ids) if ids.any?
    end

    require "csv"

    csv_data = CSV.generate(headers: true) do |csv|
      csv << [
        "ID", "Name", "Email", "Phone", "Company", "Country", "Status",
        "Lead Source", "Customer Type", "Lead Quality", "Platform",
        "Project Type", "Project Scope", "Project Estimated Cost",
        "Call Status", "Email Status", "WhatsApp Status", "LinkedIn Status",
        "Total Call Attempts", "Successful Call Attempts",
        "Assigned To", "UTM Campaign", "UTM Term", "UTM Source", "UTM Medium",
        "Created At", "Updated At"
      ]

      customers.find_each do |customer|
        csv << [
          customer.id,
          customer.name,
          customer.email,
          customer.phone,
          customer.company,
          customer.country,
          customer.status,
          customer.lead_source,
          customer.customer_type,
          customer.lead_quality,
          customer.platform,
          customer.project_type,
          customer.project_scope,
          customer.project_estimated_cost,
          customer.call_status,
          customer.email_status,
          customer.whatsapp_status,
          customer.linkedin_status,
          customer.total_call_attempts,
          customer.successful_call_attempts,
          customer.user&.name,
          customer.utm_campaign,
          customer.utm_term,
          customer.utm_source,
          customer.utm_medium,
          customer.created_at&.strftime("%Y-%m-%d %H:%M"),
          customer.updated_at&.strftime("%Y-%m-%d %H:%M")
        ]
      end
    end

    send_data csv_data,
              filename: "customers_export_#{Date.today.strftime('%Y%m%d')}.csv",
              type: "text/csv",
              disposition: "attachment"
  end

  def show
    authorize @customer

    # Rail context (the workspace's 340px left column).
    @deals      = @customer.deals.includes(:user)
    @open_tasks = @customer.tasks.where(completed: [ false, nil ]).order(due_date: :asc)

    # Conversation canvas: one chronological multi-channel stream.
    @conversation = Relay::ConversationBuilder.new(@customer).events

    if @customer.email.present? && current_user.google_auth_configured?
      CustomerEmailFetchWorker.perform_async(@customer.id, current_user.id)
    end
  end

  # Composer "Note" tab: records an internal note as a customer activity so it
  # threads into the conversation alongside calls/emails/WhatsApp.
  def add_note
    authorize @customer, :update?

    text = params[:body].to_s.strip
    if text.blank?
      respond_to do |format|
        format.turbo_stream { head :unprocessable_entity }
        format.html { redirect_to @customer, alert: "Note can't be blank." }
      end
      return
    end

    @note = @customer.customer_activities.create!(action: "note", details: text, user: current_user)

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to @customer, notice: "Note saved." }
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
        format.html { redirect_to @customer, notice: "Customer was successfully created." }
        format.json {
          # Ensure we render JSON with proper headers
          response.headers["Content-Type"] = "application/json"
          render json: { id: @customer.id, name: @customer.name, phone: @customer.phone }, status: :created
        }
      end
    rescue ActiveRecord::RecordInvalid
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json {
          response.headers["Content-Type"] = "application/json"
          render json: { errors: @customer.errors }, status: :unprocessable_entity
        }
      end
    rescue => e
      @customer.errors.add(:base, "An unexpected error occurred: #{e.message}")
      respond_to do |format|
        format.html { render :new, status: :unprocessable_entity }
        format.json {
          response.headers["Content-Type"] = "application/json"
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

      respond_to do |format|
        format.html { redirect_to @customer, notice: "Customer was successfully updated." }
        format.json { render json: { success: true, message: "Customer was successfully updated." } }
      end
    rescue ActiveRecord::RecordInvalid
      # Log validation errors for debugging
      Rails.logger.error("Customer update failed: #{@customer.errors.full_messages.join(', ')}")

      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { success: false, error: @customer.errors.full_messages.join(", ") }, status: :unprocessable_entity }
      end
    rescue => e
      # Log any unexpected errors
      Rails.logger.error("Error updating customer: #{e.message}")
      @customer.errors.add(:base, "An unexpected error occurred: #{e.message}")

      respond_to do |format|
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
      end
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

          respond_to do |format|
            format.html { redirect_to @customer, notice: "Document was successfully removed." }
            format.json { render json: { success: true, message: "Document was successfully removed." } }
          end
        else
          Rails.logger.error "Attachment not found for blob #{blob.id}"

          respond_to do |format|
            format.html { redirect_to @customer, alert: "Document not found." }
            format.json { render json: { success: false, error: "Document not found." }, status: :not_found }
          end
        end
      rescue ActiveStorage::InvalidSignature => e
        Rails.logger.error "Invalid signed ID: #{e.message}"

        respond_to do |format|
          format.html { redirect_to @customer, alert: "Invalid document reference." }
          format.json { render json: { success: false, error: "Invalid document reference." }, status: :unprocessable_entity }
        end
      rescue => e
        Rails.logger.error "Error removing document: #{e.message}"

        respond_to do |format|
          format.html { redirect_to @customer, alert: "Failed to remove document." }
          format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
        end
      end
    else
      authorize @customer, :destroy?
      @customer.destroy
      redirect_to customers_url, notice: "Customer was successfully deleted."
    end
  end

  def update_status
    @customer = Customer.find(params[:id])
    authorize @customer

    if @customer.update(status: params[:status])
      respond_to do |format|
        format.html { redirect_to @customer, notice: "Status updated successfully." }
        format.json { render json: { success: true } }
      end
    else
      respond_to do |format|
        format.html { redirect_to @customer, alert: "Failed to update status." }
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
    valid_status_types = [ "call_status", "email_status", "whatsapp_status", "linkedin_status", "customer_type" ]
    valid_status_values = case status_type
    when "call_status"
                            Customer::CALL_STATUSES.values
    when "email_status"
                            Customer::EMAIL_STATUSES.values
    when "whatsapp_status"
                            Customer::WHATSAPP_STATUSES.values
    when "linkedin_status"
                            Customer::LINKEDIN_STATUSES.values
    when "customer_type"
                            Customer::CUSTOMER_TYPES.values
    else
                            []
    end

    unless valid_status_types.include?(status_type) && valid_status_values.include?(status_value)
      respond_to do |format|
        format.html { redirect_to @customer, alert: "Invalid status type or value" }
        format.json { render json: { success: false, error: "Invalid status type or value" }, status: :unprocessable_entity }
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
      redirect_to customers_path, alert: "Please select customers and a user to assign."
      return
    end

    # Log the raw input for debugging
    Rails.logger.info("Raw customer_ids input: #{params[:customer_ids].inspect}")

    # Find customers - ensure we're parsing the IDs correctly
    customer_ids = params[:customer_ids].to_s.split(",").map(&:strip).reject(&:blank?).map(&:to_i).reject(&:zero?)

    if customer_ids.empty?
      redirect_to customers_path, alert: "No valid customers selected."
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
      redirect_to customers_path, alert: "Selected user not found."
      return
    end

    # Check if current user is a manager and is trying to assign to someone other than themselves or their associates
    if current_user.manager? && !current_user.admin?
      # Get the list of valid assignees for this manager (self + associates)
      valid_assignee_ids = [ current_user.id ] + current_user.associates.pluck(:id)

      # Check if the target user is in the valid assignees list
      unless valid_assignee_ids.include?(user.id)
        redirect_to customers_path, alert: "You can only assign customers to yourself or your team members."
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
      redirect_to customers_path, alert: "Failed to assign customers."
    end
  end

  def bulk_status_change
    authorize Customer

    if !params[:customer_ids].present? || !params[:status].present?
      redirect_to customers_path, alert: "Please select customers and a status to change."
      return
    end

    # Find customers - ensure we're parsing the IDs correctly
    customer_ids = params[:customer_ids].to_s.split(",").map(&:strip).reject(&:blank?).map(&:to_i).reject(&:zero?)

    if customer_ids.empty?
      redirect_to customers_path, alert: "No valid customers selected."
      return
    end

    # Validate status
    unless Customer::STATUSES.values.include?(params[:status])
      redirect_to customers_path, alert: "Invalid status selected."
      return
    end

    # Find customers
    customers = Customer.where(id: customer_ids)

    if customers.empty?
      redirect_to customers_path, alert: "No customers found with the selected IDs."
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
      redirect_to customers_path, alert: "Failed to update customer statuses."
    end
  end


  def analyze_phone
    authorize @customer

    if @customer.phone.blank?
      respond_to do |format|
        format.html { redirect_to @customer, alert: "Customer does not have a phone number." }
        format.json { render json: { success: false, error: "Customer does not have a phone number." }, status: :unprocessable_entity }
      end
      return
    end

    # Use force analysis for manual triggers
    if @customer.force_phone_analysis!
      respond_to do |format|
        format.html { redirect_to @customer, notice: "Enhanced phone analysis has been queued using our comprehensive location database." }
        format.json { render json: { success: true } }
      end
    else
      respond_to do |format|
        format.html { redirect_to @customer, alert: "Failed to queue phone analysis." }
        format.json { render json: { success: false, error: "Failed to queue phone analysis." }, status: :unprocessable_entity }
      end
    end
  end

  def calculate_lead_score
    authorize @customer

    begin
     @customer.calculate_lead_score

      respond_to do |format|
        format.html { redirect_to @customer, notice: "Lead score calculated successfully." }
        format.json {
          render json: {
            success: true,
            lead_score: @customer.lead_score,
            geographic_score: @customer.geographic_score,
            description_score: @customer.description_score,
            lead_score_badge: @customer.lead_score_badge,
            lead_score_color: @customer.lead_score_color,
            updated_at: @customer.lead_score_updated_at&.strftime("%b %d, %Y at %I:%M %p")
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

  def assign_to_self
    authorize @customer

    # Use update_column to bypass validations since we're only changing assignment
    # This avoids triggering document validations and other unrelated checks
    if @customer.update_column(:user_id, current_user.id)
      respond_to do |format|
        format.html { redirect_to customers_path, notice: "Customer '#{@customer.name}' successfully assigned to you." }
        format.json { render json: { success: true, user_id: current_user.id, user_name: current_user.name } }
      end
    else
      respond_to do |format|
        format.html { redirect_to customers_path, alert: "Failed to assign customer." }
        format.json { render json: { success: false, errors: [ "Assignment failed" ] }, status: :unprocessable_entity }
      end
    end
  end

  def upload_documents
    authorize @customer, :update?

    if params[:documents].present?
      uploaded_count = 0

      params[:documents].each do |document|
        @customer.documents.attach(document)
        uploaded_count += 1
      end

      respond_to do |format|
        format.html { redirect_to @customer, notice: "Successfully uploaded #{uploaded_count} document(s)." }
        format.json { render json: { success: true, count: uploaded_count, message: "Successfully uploaded #{uploaded_count} document(s)." } }
      end
    else
      respond_to do |format|
        format.html { redirect_to @customer, alert: "No documents selected." }
        format.json { render json: { success: false, error: "No documents selected." }, status: :unprocessable_entity }
      end
    end
  rescue => e
    Rails.logger.error("Error uploading documents: #{e.message}")
    respond_to do |format|
      format.html { redirect_to @customer, alert: "Failed to upload documents." }
      format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
    end
  end

  def mark_lead_quality
    authorize @customer

    quality = params[:quality]

    unless %w[good bad].include?(quality)
      respond_to do |format|
        format.html { redirect_to @customer, alert: "Invalid lead quality value." }
        format.json { render json: { success: false, error: 'Invalid quality value. Must be "good" or "bad".' }, status: :unprocessable_entity }
      end
      return
    end

    begin
      @customer.update!(
        lead_quality: quality,
        lead_quality_marked_at: Time.current,
        lead_quality_marked_by_id: current_user.id
      )

      # Trigger Google Ads conversion upload if gclid is present
      if @customer.gclid.present? || @customer.gbraid.present? || @customer.wbraid.present?
        GoogleAdsConversionWorker.perform_async(@customer.id)
      end

      respond_to do |format|
        format.html { redirect_to @customer, notice: "Lead marked as #{quality}." }
        format.json { render json: { success: true, quality: quality } }
      end
    rescue => e
      Rails.logger.error("Error marking lead quality for customer #{@customer.id}: #{e.message}")
      respond_to do |format|
        format.html { redirect_to @customer, alert: "Failed to update lead quality." }
        format.json { render json: { success: false, error: e.message }, status: :unprocessable_entity }
      end
    end
  end

  private

  # Relay shell adoption: the Leads list (Phase 3) and the lead workspace
  # show/add_note (Phase 4) use the relay layout. Edit/new keep the legacy
  # tenant form until a later phase ports them.
  RELAY_ACTIONS = %w[index show add_note].freeze

  def choose_layout
    RELAY_ACTIONS.include?(action_name) ? "relay" : "tenant"
  end

  def set_customer
    @customer = Customer.find(params[:id])
  end

  def customer_params
    # Only permit parameters that are actually in the form
    permitted_params = [
      :name, :email, :phone, :address, :company, :notes,
      :lead_source, :linkedin_url, :meta_lead_id, :ccr_link, :project_estimated_cost,
      :project_type, :idea_description, :country, :status, :call_status,
      :email_status, :whatsapp_status, :linkedin_status, :upwork_profile, :exhaust_status,
      :preferred_calling_time, :platform, :project_scope, :repeat_lead, documents: []
    ]

    # Only admins can assign customers to users
    if current_user&.admin?
      permitted_params << :user_id
    end

    params.require(:customer).permit(permitted_params)
  end

  def apply_filters(scope)
    if params[:user_id].present? && (current_user&.admin? || current_user&.manager?)
      if params[:user_id] == "unassigned"
        scope = scope.where(user_id: nil)
      else
        scope = scope.assigned_to(params[:user_id])
      end
    end
    scope = scope.search(params[:search])

    scope = scope.where(status: params[:status]) if params[:status].present?

    if params[:lead_source].present?
      lead_sources = params[:lead_source].is_a?(Array) ? params[:lead_source].reject(&:blank?) : [ params[:lead_source] ].reject(&:blank?)
      scope = scope.where(lead_source: lead_sources) if lead_sources.any?
    end

    scope = scope.where(customer_type: params[:customer_type]) if params[:customer_type].present?

    if params[:start_date].present?
      scope = scope.where("customers.created_at >= ?", Date.parse(params[:start_date]).beginning_of_day)
    end
    if params[:end_date].present?
      scope = scope.where("customers.created_at <= ?", Date.parse(params[:end_date]).end_of_day)
    end

    scope
  end

  def require_login
    unless session[:user_id]
      flash[:error] = "You must be logged in to access this section"
      redirect_to root_path
    end
  end
end
