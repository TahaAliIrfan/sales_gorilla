class CustomerFollowupsController < ApplicationController
  layout 'dashboard'
  before_action :require_login
  before_action :set_customer
  
  def new
    @followup = {
      date: Date.tomorrow,
      time: Time.current.strftime("%H:%M"),
      notes: ""
    }
    
    authorize @customer, :update?
  end
  
  def create
    authorize @customer, :update?
    
    followup_date = Time.zone.parse("#{params[:followup][:date]} #{params[:followup][:time]}")
    followup_notes = params[:followup][:notes]
    
    if @customer.schedule_followup(followup_date, followup_notes, current_user)
      # Create an activity entry for the follow-up
      @customer.customer_activities.create!(
        activity_type: 'follow_up_scheduled',
        description: "Follow-up scheduled for #{followup_date.strftime('%b %d, %Y at %I:%M %p')}",
        user_id: current_user.id
      )
      
      redirect_to @customer, notice: 'Follow-up scheduled successfully.'
    else
      flash.now[:alert] = 'Unable to schedule follow-up. Please try again.'
      render :new
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