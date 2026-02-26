# frozen_string_literal: true

class InvoicesController < ApplicationController
  layout 'dashboard'
  before_action :require_login
  before_action :set_customer
  before_action :set_invoice, only: [:show, :edit, :update, :download_pdf]

  def index
    @invoices = @customer.invoices.includes(:milestone, :user).order(created_at: :desc)
    authorize Invoice.new(customer: @customer)
  end

  def show
    authorize @invoice
  end

  def new
    @invoice = @customer.invoices.build(
      issue_date: Date.current,
      due_date: Date.current + 30.days,
      milestone_id: params[:milestone_id]
    )
    if @invoice.milestone.present?
      @invoice.populate_from_milestone!(@invoice.milestone)
      @invoice.project_name = @invoice.milestone.name
    end
    @milestones = @customer.milestones.includes(:milestone_items).order(:created_at)
    authorize @invoice
  end

  def create
    milestone = Milestone.find_by(id: params[:invoice][:milestone_id], customer_id: @customer.id)
    if milestone.blank?
      flash[:error] = "Please select a milestone"
      @milestones = @customer.milestones.includes(:milestone_items).order(:created_at)
      @invoice = @customer.invoices.build(invoice_params)
      authorize Invoice.new(customer: @customer)
      render :new, status: :unprocessable_entity and return
    end

    @invoice = @customer.invoices.build(invoice_params)
    @invoice.user = current_user
    @invoice.milestone = milestone
    @invoice.populate_from_milestone!(milestone)

    authorize @invoice

    if @invoice.save
      redirect_to customer_invoice_path(@customer, @invoice), notice: "Invoice created successfully."
    else
      @milestones = @customer.milestones.includes(:milestone_items).order(:created_at)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @invoice
    @milestones = @customer.milestones.includes(:milestone_items).order(:created_at)
  end

  def update
    @invoice = @customer.invoices.find(params[:id])
    authorize @invoice

    if @invoice.update(invoice_params)
      redirect_to customer_invoice_path(@customer, @invoice), notice: "Invoice updated successfully."
    else
      @milestones = @customer.milestones.includes(:milestone_items).order(:created_at)
      render :edit, status: :unprocessable_entity
    end
  end

  def download_pdf
    authorize @invoice

    pdf = InvoicePdfService.new(@invoice).generate_pdf
    filename = "Invoice_#{@invoice.invoice_number}_#{Date.current.strftime('%Y%m%d')}.pdf"

    # Attach to invoice for future reference
    @invoice.pdf_file.attach(
      io: StringIO.new(pdf.render),
      filename: filename,
      content_type: 'application/pdf'
    ) unless @invoice.pdf_file.attached?

    send_data pdf.render,
      filename: filename,
      type: 'application/pdf',
      disposition: 'attachment'
  end

  private

  def set_customer
    @customer = policy_scope(Customer).find(params[:customer_id])
  end

  def set_invoice
    @invoice = @customer.invoices.find(params[:id])
  end

  def invoice_params
    params.require(:invoice).permit(
      :project_name, :description, :issue_date, :due_date, :tax_rate,
      invoice_line_items_attributes: [:id, :description, :amount, :position, :_destroy]
    )
  end
end
