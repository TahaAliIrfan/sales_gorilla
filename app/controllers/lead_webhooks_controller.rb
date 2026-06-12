class LeadWebhooksController < ApplicationController
  layout 'dashboard'
  before_action :require_login
  before_action :require_admin
  before_action :set_lead_webhook, only: [:edit, :update, :destroy, :toggle_active]

  def index
    @lead_webhooks = LeadWebhook.order(created_at: :desc)
  end

  def new
    @lead_webhook = LeadWebhook.new
  end

  def create
    @lead_webhook = LeadWebhook.new(lead_webhook_params)
    if @lead_webhook.save
      redirect_to lead_webhooks_path, notice: "Webhook \"#{@lead_webhook.name}\" created. Paste its URL into Zapier."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @lead_webhook.update(lead_webhook_params)
      redirect_to lead_webhooks_path, notice: 'Webhook updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def toggle_active
    @lead_webhook.update!(active: !@lead_webhook.active)
    redirect_to lead_webhooks_path, notice: "Webhook #{@lead_webhook.active? ? 'activated' : 'paused'}."
  end

  def destroy
    @lead_webhook.destroy
    redirect_to lead_webhooks_path, notice: 'Webhook deleted. Its URL will no longer accept leads.'
  end

  private

  def set_lead_webhook
    @lead_webhook = LeadWebhook.find(params[:id])
  end

  def lead_webhook_params
    params.require(:lead_webhook).permit(:name, :lead_source, :description, :active)
  end
end
