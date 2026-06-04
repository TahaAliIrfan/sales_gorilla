# frozen_string_literal: true

class PublicInvoicesController < ApplicationController
  layout "relay_public"
  skip_before_action :require_login, raise: false
  skip_before_action :set_tasks_notification_counts
  skip_before_action :set_notification_counts

  before_action :set_invoice_by_token

  # Branding for the public page comes from the invoice's tenant organization
  # (Invoice acts_as_tenant(:organization) → belongs_to :organization). The page
  # is served on the ROOT domain with no current_organization, so the layout and
  # view read @organization directly — never current_organization.
  helper_method :public_invoice_organization

  def show
    if @invoice.publicly_viewable?
      render :show
    else
      @reason = unavailable_reason
      render :unavailable, layout: "public", status: :ok
    end
  end

  def download_pdf
    unless @invoice.publicly_viewable?
      @reason = unavailable_reason
      render :unavailable, layout: "public", status: :gone
      return
    end

    pdf = InvoicePdfService.new(@invoice).generate_pdf
    filename = "Invoice_#{@invoice.invoice_number}_#{Date.current.strftime('%Y%m%d')}.pdf"
    send_data pdf.render,
      filename: filename,
      type: "application/pdf",
      disposition: "attachment"
  end

  def upload_payment_proof
    unless @invoice.publicly_viewable?
      @reason = unavailable_reason
      render :unavailable, layout: "public", status: :gone
      return
    end

    file = params[:invoice].present? ? params[:invoice][:payment_proof] : params[:payment_proof]
    if file.present?
      @invoice.payment_proof.attach(file)
      if @invoice.payment_proof.attached?
        redirect_to public_invoice_path(@invoice.public_token), notice: "Payment proof uploaded successfully. Thank you!"
      else
        flash.now[:error] = "Could not upload file. Please use an image or PDF under 10MB."
        render :show, status: :unprocessable_entity
      end
    else
      redirect_to public_invoice_path(@invoice.public_token), flash: { error: "Please select a file first." }
    end
  end

  private

  # The tenant org that owns this invoice — drives all branding on the public
  # page (logo, name, brand color ramp). Loaded outside any tenant scope.
  def public_invoice_organization
    @invoice&.organization
  end

  def set_invoice_by_token
    @invoice = Invoice.find_by!(public_token: params[:token])
  rescue ActiveRecord::RecordNotFound
    render "public_invoices/not_found", layout: "public", status: :not_found
  end

  def unavailable_reason
    if @invoice.paid?
      :paid
    elsif @invoice.expired?
      :expired
    else
      :unavailable
    end
  end
end
