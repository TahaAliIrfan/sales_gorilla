class CustomerFollowupsController < ApplicationController
  layout 'dashboard'
  before_action :require_login
  before_action :set_customer
  
  def new
    # Since we're now using a modal, redirect back to the customer page
    redirect_to customer_path(params[:customer_id])
  end
  
  def create
    authorize @customer, :update?
    
    followup_date = Time.zone.parse("#{params[:followup][:date]} #{params[:followup][:time]}")
    followup_notes = params[:followup][:notes]
    add_to_calendar = params[:followup][:add_to_calendar] == "1"
    
    if @customer.schedule_followup(followup_date, followup_notes, current_user, add_to_calendar)
      # Create an activity entry for the follow-up
      @customer.customer_activities.create!(
        action: 'follow_up_scheduled',
        details: "Follow-up scheduled for #{followup_date.strftime('%b %d, %Y at %I:%M %p')}",
        user_id: current_user.id
      )
      
      respond_to do |format|
        format.html { redirect_to @customer, notice: 'Follow-up scheduled successfully.' }
        format.json { render json: { success: true, message: 'Follow-up scheduled successfully.' }, status: :ok }
      end
    else
      respond_to do |format|
        format.html do
          flash.now[:alert] = 'Unable to schedule follow-up. Please try again.'
          render :new
        end
        format.json { render json: { success: false, error: 'Unable to schedule follow-up. Please try again.' }, status: :unprocessable_entity }
      end
    end
  end
  
  private
  
  def set_customer
    @customer = Customer.find(params[:customer_id])
  end
  
  def require_login
    unless session[:user_id]
      redirect_to root_path, alert: "You must be logged in to access this page."
    end
  end
end 