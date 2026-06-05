# frozen_string_literal: true

class AllInvoicesController < ApplicationController
  layout "relay"
  before_action :require_login

  def index
    @invoices = policy_scope(Invoice)
      .includes(:customer, :milestone, :user)
      .order(created_at: :desc)

    # Filters
    @invoices = @invoices.where(status: params[:status]) if params[:status].present?
    if params[:search].present?
      search_term = "%#{params[:search].strip}%"
      @invoices = @invoices.joins(:customer).where("customers.name ILIKE ?", search_term)
    end
    @invoices = @invoices.where("issue_date >= ?", params[:from_date]) if params[:from_date].present?
    @invoices = @invoices.where("issue_date <= ?", params[:to_date]) if params[:to_date].present?

    @invoices = @invoices.page(params[:page]).per(20)

    # For customer filter dropdown (admin sees all, others see their customers)
    @customers = policy_scope(Customer).order(:name)

    authorize Invoice.new(customer: Customer.new)
  end
end
