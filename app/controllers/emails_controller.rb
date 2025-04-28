class EmailsController < ApplicationController
  before_action :require_login
  before_action :set_customer
  before_action :authorize_customer
  before_action :set_email, only: [:show, :mark_as_read]
  
  def index
    @emails = @customer.emails.includes(:email_attachments).order(created_at: :desc).page(params[:page]).per(20)
    
    respond_to do |format|
      format.html
      format.json { render json: @emails.to_json(include: :email_attachments) }
    end
  end
  
  def show
    @email.mark_as_read! if @email.received?
    
    respond_to do |format|
      format.html
      format.json { render json: @email.to_json(include: :email_attachments) }
    end
  end
  
  def new
    @email = Email.new(customer: @customer, user: current_user)
  end
  
  def create
    # Validate parameters
    unless params[:subject].present? && params[:body].present?
      flash[:error] = "Subject and body are required"
      render :new and return
    end
    
    # Handle file attachments
    attachment_data = []
    if params[:attachments].present?
      params[:attachments].each do |attachment|
        # Create a temporary file
        temp_file = Tempfile.new(['attachment', File.extname(attachment.original_filename)])
        temp_file.binmode
        temp_file.write(attachment.read)
        temp_file.rewind
        
        # Add to attachment data
        attachment_data << {
          filename: attachment.original_filename,
          content_type: attachment.content_type,
          path: temp_file.path
        }
      end
    end
    
    # Send the email
    gmail_service = GmailService.new(current_user)
    @email = gmail_service.send_email(
      @customer,
      params[:subject],
      params[:body],
      nil, # Let the service generate the plain text version
      attachment_data
    )
    
    # Clean up temp files
    attachment_data.each do |attachment|
      File.unlink(attachment[:path]) if File.exist?(attachment[:path])
    end
    
    if @email
      flash[:success] = "Email successfully sent"
      redirect_to customer_emails_path(@customer)
    else
      flash[:error] = "Failed to send email"
      render :new
    end
  end
  
  def fetch
    unless current_user.google_auth_configured?
      flash[:error] = "Google OAuth is not configured for your account"
      redirect_to customer_emails_path(@customer) and return
    end

    gmail_service = GmailService.new(current_user)
    emails = gmail_service.fetch_emails_for_customer(@customer)
    
    if emails.any?
      flash[:success] = "Successfully fetched #{emails.count} emails"
    else
      flash[:notice] = "No new emails found"
    end
    
    redirect_to customer_emails_path(@customer)
  end
  
  def mark_as_read
    @email.mark_as_read!
    
    respond_to do |format|
      format.html { redirect_to customer_email_path(@customer, @email) }
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