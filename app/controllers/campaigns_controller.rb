class CampaignsController < ApplicationController
  layout 'dashboard'
  before_action :set_campaign, only: [:show, :edit, :update, :destroy, :send_now, :schedule, :restart, :stop, :add_customers, :remove_customer]

  def index
    @campaigns = policy_scope(Campaign).order(created_at: :desc)
  end

  def show
    authorize @campaign
    @customers = @campaign.customers.order(:name)
    @available_customers = get_accessible_customers.where.not(id: @customers.pluck(:id)).order(:name)
    @customer_groups = current_user.customer_groups
    @executions = @campaign.campaign_executions.includes(:customer).order(:scheduled_at)
    @templates = approved_templates
  end

  def new
    @campaign = Campaign.new
    authorize @campaign
    @customers = get_accessible_customers
    @customer_groups = current_user.customer_groups
    @templates = approved_templates
  end

  def edit
    authorize @campaign
    @customers = get_accessible_customers
    @templates = approved_templates
  end

  # Pull the latest approved templates from Twilio/Meta into whatsapp_templates.
  def sync_templates
    unless current_user.admin?
      redirect_back fallback_location: new_campaign_path, alert: 'Only admins can sync templates.' and return
    end

    begin
      TwilioWhatsappTemplatesService.new.sync!
      redirect_back fallback_location: new_campaign_path,
                    notice: "#{WhatsappTemplate.approved.count} approved template(s) available."
    rescue StandardError => e
      redirect_back fallback_location: new_campaign_path, alert: "Template sync failed: #{e.message}"
    end
  end

  def create
    # Handle timezone conversion for scheduled_at
    params_with_timezone = campaign_params
    if params_with_timezone[:scheduled_at].present?
      # The datetime comes from the form as a string in Pakistan time
      # We need to parse it in Pakistan timezone, then Rails will store it as UTC
      params_with_timezone[:scheduled_at] = Time.zone.parse(params_with_timezone[:scheduled_at])
    end

    @campaign = current_user.campaigns.build(params_with_timezone)
    authorize @campaign

    if @campaign.save
      # Add selected customers
      if params[:campaign][:customer_ids].present?
        customer_ids = params[:campaign][:customer_ids].reject(&:blank?)
        @campaign.add_customers(customer_ids)
      end

      redirect_to @campaign, notice: 'Campaign was successfully created.'
    else
      @customers = get_accessible_customers
      @customer_groups = current_user.customer_groups
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @campaign

    puts "=" * 80
    puts "UPDATE CAMPAIGN"
    puts "Campaign ID: #{@campaign.id}"
    puts "Current scheduled_at: #{@campaign.scheduled_at}"
    puts "Params received: #{campaign_params.inspect}"
    puts "=" * 80

    # Handle timezone conversion for scheduled_at
    params_with_timezone = campaign_params
    if params_with_timezone[:scheduled_at].present?
      puts "Original scheduled_at param: #{params_with_timezone[:scheduled_at]}"
      # The datetime comes from the form as a string in Pakistan time
      # We need to parse it in Pakistan timezone, then Rails will store it as UTC
      params_with_timezone[:scheduled_at] = Time.zone.parse(params_with_timezone[:scheduled_at])
      puts "Parsed scheduled_at: #{params_with_timezone[:scheduled_at]}"
    end

    puts "Final params: #{params_with_timezone.inspect}"

    if @campaign.update(params_with_timezone)
      puts "Campaign updated successfully!"
      puts "New scheduled_at: #{@campaign.reload.scheduled_at}"

      # If campaign has customers and a future scheduled_at, auto-schedule it
      if @campaign.draft? && @campaign.scheduled_at.present? && @campaign.scheduled_at > Time.current && @campaign.campaign_executions.count > 0
        puts "Auto-scheduling campaign after update..."
        @campaign.schedule_for_later!
      end

      puts "=" * 80
      redirect_to @campaign, notice: 'Campaign was successfully updated.'
    else
      puts "Campaign update FAILED"
      puts "Errors: #{@campaign.errors.full_messages}"
      puts "=" * 80
      @customers = get_accessible_customers
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @campaign
    @campaign.destroy
    redirect_to campaigns_url, notice: 'Campaign was successfully deleted.'
  end

  def send_now
    authorize @campaign

    begin
      @campaign.execute_now!
      redirect_to @campaign, notice: 'Campaign is being sent. Check the executions tab for progress.'
    rescue StandardError => e
      redirect_to @campaign, alert: "Failed to send campaign: #{e.message}"
    end
  end

  def schedule
    authorize @campaign

    begin
      if @campaign.scheduled_at.blank?
        redirect_to @campaign, alert: 'Please set a scheduled time before scheduling the campaign.'
      elsif @campaign.scheduled_at <= Time.current
        redirect_to @campaign, alert: 'Scheduled time must be in the future. Use "Send Now" for immediate sending.'
      else
        @campaign.schedule_for_later!
        redirect_to @campaign, notice: "Campaign scheduled for #{@campaign.scheduled_at.strftime('%b %d, %Y at %I:%M %p')}."
      end
    rescue StandardError => e
      redirect_to @campaign, alert: "Failed to schedule campaign: #{e.message}"
    end
  end

  def restart
    authorize @campaign

    begin
      @campaign.restart!
      redirect_to edit_campaign_path(@campaign), notice: 'Campaign restarted! Update the message and scheduled time, then save to re-send.'
    rescue StandardError => e
      redirect_to @campaign, alert: "Failed to restart campaign: #{e.message}"
    end
  end

  def stop
    authorize @campaign

    begin
      @campaign.stop!
      redirect_to @campaign, notice: 'Campaign stopped! All pending messages have been cancelled.'
    rescue StandardError => e
      redirect_to @campaign, alert: "Failed to stop campaign: #{e.message}"
    end
  end

  def add_customers
    authorize @campaign

    if params[:customer_ids].present?
      customer_ids = params[:customer_ids].is_a?(Array) ? params[:customer_ids] : [params[:customer_ids]]
      customer_ids = customer_ids.reject(&:blank?)

      @campaign.add_customers(customer_ids)
      redirect_to @campaign, notice: "#{customer_ids.count} customer(s) added to campaign."
    elsif params[:group_id].present?
      # Add all customers from a group
      group = CustomerGroup.find(params[:group_id])
      customer_ids = group.customers.pluck(:id)

      @campaign.add_customers(customer_ids)
      redirect_to @campaign, notice: "#{customer_ids.count} customer(s) from group '#{group.name}' added to campaign."
    else
      redirect_to @campaign, alert: 'No customers selected.'
    end
  end

  def remove_customer
    authorize @campaign
    execution = @campaign.campaign_executions.find_by(customer_id: params[:customer_id])

    if execution
      execution.destroy
      redirect_to @campaign, notice: 'Customer removed from campaign.'
    else
      redirect_to @campaign, alert: 'Customer not found in campaign.'
    end
  end

  private

  def set_campaign
    @campaign = Campaign.find(params[:id])
  end

  def campaign_params
    params.require(:campaign).permit(:name, :scheduled_at, :content_sid, content_variables: {})
  end

  def approved_templates
    WhatsappTemplate.approved.ordered.reject(&:requires_media_upload?)
  end

  # Twilio sends to the phone number, so campaign recipients must have one.
  def get_accessible_customers
    scope =
      if current_user.admin?
        Customer.all
      elsif current_user.manager?
        associate_ids = current_user.associates.pluck(:id)
        Customer.where(user_id: [current_user.id] + associate_ids)
      else
        current_user.customers
      end

    scope.where.not(phone: [nil, '']).order(:name)
  end
end
