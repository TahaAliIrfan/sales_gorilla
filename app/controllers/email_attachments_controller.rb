class EmailAttachmentsController < ApplicationController
  before_action :require_login
  before_action :set_customer
  before_action :authorize_customer
  before_action :set_email
  before_action :set_attachment

  # GET /customers/:customer_id/emails/:email_id/attachments/:id
  def show
    redirect_to rails_blob_path(@attachment, disposition: "inline")
  end

  # GET /customers/:customer_id/emails/:email_id/attachments/:id/download
  def download
    redirect_to rails_blob_path(@attachment, disposition: "attachment")
  end

  private

  def set_customer
    @customer = Customer.find(params[:customer_id])
  end

  def set_email
    @email = @customer.emails.find(params[:email_id])
  end

  def set_attachment
    @attachment = @email.attachments.find(params[:id])
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
