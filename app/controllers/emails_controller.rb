class EmailsController < ApplicationController
  before_action :require_login
  before_action :set_customer
  before_action :authorize_customer
  before_action :set_email, only: [:show, :mark_as_read]
  
  def index
    respond_to do |format|
      format.html { redirect_to customer_path(@customer, anchor: 'emails') }
      format.json { 
        @emails = @customer.emails.with_attached_attachments.order(created_at: :desc).page(params[:page]).per(20)
        # Build JSON with attachments
        emails_json = @emails.map do |email|
          email_json = email.as_json
          email_json['attachments'] = email.attachments_json
          email_json
        end
        render json: emails_json
      }
    end
  end
  
  def show
    @email.mark_as_read! if @email.received?
    
    respond_to do |format|
      format.html { redirect_to customer_path(@customer, anchor: 'emails') }
      format.json { 
        # Include thread emails if gmail_thread_id exists
        thread_emails = []
        if @email.gmail_thread_id.present?
          thread_emails = @customer.emails
            .with_attached_attachments
            .where(gmail_thread_id: @email.gmail_thread_id)
            .where.not(id: @email.id)
            .order(created_at: :asc)
            .limit(20)
        end
        
        # Build email JSON with attachments
        email_json = @email.as_json(
          only: [:id, :subject, :from_email, :to_email, :from_name, :to_name, 
                 :body_html, :body_text, :snippet, :status, :message_id,
                 :gmail_thread_id, :read_at, :sent_at, :received_at, :created_at, :has_attachments],
          methods: [:display_subject, :sender_name, :receiver_name, :formatted_date]
        )
        
        # Add attachments
        email_json['attachments'] = @email.attachments_json
        
        # Build thread emails JSON with attachments
        thread_emails_json = thread_emails.map do |thread_email|
          te_json = thread_email.as_json(
            only: [:id, :subject, :from_email, :to_email, :from_name, :to_name,
                   :body_html, :body_text, :snippet, :status, :sent_at, :received_at, :created_at, :has_attachments],
            methods: [:display_subject, :sender_name, :receiver_name, :formatted_date]
          )
          te_json['attachments'] = thread_email.attachments_json
          te_json
        end
        
        render json: email_json.merge(thread_emails: thread_emails_json)
      }
    end
  end
  
  def new
    # Redirect to customer show page - compose functionality is now in a modal
    redirect_to customer_path(@customer, anchor: 'emails', compose: true)
  end
  
  def create
    # Extract email params (support both nested and flat params)
    email_params = params[:email] || params
    subject = email_params[:subject]
    body = email_params[:body_text] || email_params[:body] || email_params[:body_html]
    
    # Validate parameters
    unless subject.present? && body.present?
      respond_to do |format|
        format.html {
          flash[:error] = "Subject and body are required"
          render :new
        }
        format.json { render json: { error: "Subject and body are required" }, status: :unprocessable_entity }
      end
      return
    end
    
    # Handle file attachments - store content in memory to avoid temp file issues
    attachment_data = []
    attachments_param = email_params[:attachments] || params[:attachments]
    Rails.logger.info("Attachments param: #{attachments_param.inspect}")
    
    if attachments_param.present?
      attachments_param.each do |attachment|
        Rails.logger.info("Processing attachment: #{attachment.class.name}")
        
        # Skip if attachment is not a valid file upload (e.g., empty string)
        next unless attachment.respond_to?(:original_filename) && attachment.original_filename.present?
        
        Rails.logger.info("Valid attachment found: #{attachment.original_filename} (#{attachment.content_type})")
        
        # Read the file content into memory
        file_content = attachment.read
        Rails.logger.info("Read #{file_content.bytesize} bytes into memory")
        
        # Add to attachment data with content instead of path
        attachment_data << {
          filename: attachment.original_filename,
          content_type: attachment.content_type,
          content: file_content,
          size: file_content.bytesize
        }
      end
    end
    
    Rails.logger.info("Total attachments to send: #{attachment_data.length}")
    
    # Send the email (with thread info if replying)
    gmail_service = GmailService.new(current_user)
    
    # Pass thread parameters if this is a reply
    thread_options = {}
    # Support both nested and flat params for thread options
    in_reply_to = email_params[:in_reply_to] || params[:in_reply_to]
    gmail_thread_id = email_params[:gmail_thread_id] || params[:gmail_thread_id]
    
    thread_options[:in_reply_to] = in_reply_to if in_reply_to.present?
    thread_options[:thread_id] = gmail_thread_id if gmail_thread_id.present?
    
    @email = gmail_service.send_email(
      @customer,
      subject,
      body,
      nil, # Let the service generate the plain text version
      attachment_data,
      thread_options
    )
    
    # No temp file cleanup needed - we store content in memory now
    
    if @email
      UserKpiRecord.track!(current_user&.id, :emails_sent)
      respond_to do |format|
        format.html {
          flash[:success] = "Email successfully sent"
          redirect_to customer_path(@customer, anchor: 'emails')
        }
        format.json { render json: { success: true, message: "Email sent successfully" } }
      end
    else
      respond_to do |format|
        format.html {
          flash[:error] = "Failed to send email"
          redirect_to customer_path(@customer, anchor: 'emails')
        }
        format.json { render json: { error: "Failed to send email" }, status: :unprocessable_entity }
      end
    end
  end
  
  # Sync this customer's emails from the ASSIGNED user's Gmail (not the viewer's).
  def fetch
    rep = @customer.user

    unless rep
      flash[:error] = "This customer isn't assigned to anyone, so there's no Gmail account to sync from."
      redirect_to customer_path(@customer, anchor: 'emails') and return
    end

    unless rep.google_auth_configured?
      flash[:error] = "#{rep.name}'s Google account isn't connected, so their emails can't be synced."
      redirect_to customer_path(@customer, anchor: 'emails') and return
    end

    gmail_service = GmailService.new(rep)
    emails = gmail_service.fetch_emails_for_customer(@customer)
    @customer.update(last_email_fetched_at: Time.current)

    if emails.any?
      flash[:success] = "Synced #{emails.count} emails from #{rep.name}'s Gmail"
    else
      flash[:notice] = "No new emails found in #{rep.name}'s Gmail"
    end

    redirect_to customer_path(@customer, anchor: 'emails')
  rescue Google::Apis::AuthorizationError, Signet::AuthorizationError => e
    Rails.logger.warn("EmailsController#fetch auth error for customer #{@customer.id}: #{e.message}")
    flash[:error] = "Couldn't access #{rep&.name}'s Gmail — authorization expired. They may need to reconnect Google in Settings."
    redirect_to customer_path(@customer, anchor: 'emails')
  end
  
  def mark_as_read
    @email.mark_as_read!
    
    respond_to do |format|
      format.html { redirect_to customer_path(@customer, anchor: 'emails') }
      format.json { render json: { success: true } }
    end
  end
  
  private
  
  def set_customer
    @customer = Customer.find(params[:customer_id])
  end
  
  def set_email
    @email = @customer.emails.find(params[:id])
  end
  
  def authorize_customer
    authorize @customer, :show?
  end
  
  def require_login
    unless current_user
      flash[:error] = "You must be logged in to access this section"
      redirect_to login_path and return
    end
  end
end 