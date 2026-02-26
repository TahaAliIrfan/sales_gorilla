# frozen_string_literal: true

class PublicInvoicesController < ApplicationController
  layout "public"
  skip_before_action :require_login, raise: false
  skip_before_action :set_tasks_notification_counts
  skip_before_action :set_notification_counts

  before_action :set_invoice_by_token

  def show
    if @invoice.publicly_viewable?
      render :show
    else
      @reason = unavailable_reason
      render :unavailable, status: :ok
    end
  end

  def download_pdf
    unless @invoice.publicly_viewable?
      @reason = unavailable_reason
      render :unavailable, status: :gone
      return
    end

    pdf = InvoicePdfService.new(@invoice).generate_pdf
    filename = "Invoice_#{@invoice.invoice_number}_#{Date.current.strftime('%Y%m%d')}.pdf"
    send_data pdf.render,
      filename: filename,
      type: 'application/pdf',
      disposition: 'attachment'
  end

  def upload_payment_proof
    unless @invoice.publicly_viewable?
      @reason = unavailable_reason
      render :unavailable, status: :gone
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
