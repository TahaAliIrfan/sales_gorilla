class ReportsController < ApplicationController
  layout 'dashboard'
  before_action :require_login
  before_action :require_admin, only: [:index]

  def index
    setup_date_filters

    @users = User.active_users.where.not(id: User.joins(:roles).where(roles: { name: 'admin' }).select(:id))

    prepare_user_performance
    prepare_daily_customer_details if show_daily_details?
    prepare_customer_status_overview
  end

  def my_reports
    setup_date_filters

    @users = [current_user]

    prepare_user_performance
    prepare_daily_customer_details if show_daily_details?
    prepare_customer_status_overview

    render 'user_reports'
  end

  private

  def require_login
    unless session[:user_id]
      flash[:error] = "You must be logged in to access this section"
      redirect_to root_path
    end
  end

  def require_admin
    unless current_user&.admin?
      flash[:error] = "You must be an admin to access reports"
      redirect_to root_path
    end
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def setup_date_filters
    @filter_range = params[:filter_range] || 'today'
    @custom_start_date = params[:start_date].present? ? Date.parse(params[:start_date]) : nil
    @custom_end_date = params[:end_date].present? ? Date.parse(params[:end_date]) : nil

    case @filter_range
    when 'today'
      @start_date = Time.current.beginning_of_day
      @end_date = Time.current.end_of_day
    when 'yesterday'
      @start_date = 1.day.ago.beginning_of_day
      @end_date = 1.day.ago.end_of_day
    when 'last_week'
      @start_date = 1.week.ago.beginning_of_week(:monday)
      @end_date = 1.week.ago.end_of_week(:monday).end_of_day
    when 'month'
      @start_date = Time.current.beginning_of_month
      @end_date = Time.current.end_of_day
    when 'custom'
      @start_date = @custom_start_date&.beginning_of_day || 30.days.ago.beginning_of_day
      @end_date = @custom_end_date&.end_of_day || Time.current.end_of_day
    else
      @start_date = Time.current.beginning_of_day
      @end_date = Time.current.end_of_day
    end
  end

  def show_daily_details?
    @filter_range.in?(%w[today yesterday])
  end

  def date_range
    @start_date..@end_date
  end

  def prepare_user_performance
    user_ids = @users.map(&:id)

    customer_scope = Customer.where(user_id: user_ids, created_at: date_range)

    leads_by_user = customer_scope.group(:user_id).count

    calls_by_user = customer_scope.group(:user_id).sum(:total_call_attempts)

    connected_by_user = customer_scope.group(:user_id).sum(:successful_call_attempts)

    emails_by_user = Email.joins(:customer)
                          .where(customers: { user_id: user_ids })
                          .where(emails: { created_at: date_range, status: 'sent' })
                          .group("customers.user_id").count

    whatsapp_by_user = Message.joins(:customer)
                              .where(customers: { user_id: user_ids })
                              .where(messages: { created_at: date_range, direction: 'outbound' })
                              .group("customers.user_id").count

    deals_by_user = Deal.where(user_id: user_ids, created_at: date_range)
                        .group(:user_id).count

    @user_performance = @users.map do |user|
      {
        user: user,
        leads_assigned: leads_by_user[user.id] || 0,
        calls_attempted: calls_by_user[user.id] || 0,
        connected_calls: connected_by_user[user.id] || 0,
        emails_sent: emails_by_user[user.id] || 0,
        whatsapp_sent: whatsapp_by_user[user.id] || 0,
        deals: deals_by_user[user.id] || 0
      }
    end
  end

  def prepare_daily_customer_details
    user_ids = @users.map(&:id)

    call_customer_ids = Recording.where(date: date_range, user_id: user_ids).distinct.pluck(:customer_id)
    email_customer_ids = Email.where(created_at: date_range, user_id: user_ids).distinct.pluck(:customer_id)
    whatsapp_customer_ids = Message.joins(:customer)
                                    .where(customers: { user_id: user_ids })
                                    .where(messages: { created_at: date_range })
                                    .distinct.pluck(:customer_id)

    all_customer_ids = (call_customer_ids + email_customer_ids + whatsapp_customer_ids).uniq

    @daily_customer_details = []
    return if all_customer_ids.empty?

    customers = Customer.where(id: all_customer_ids).includes(:user)

    recordings_data = Recording.where(date: date_range, customer_id: all_customer_ids)
                               .group(:customer_id)
                               .pluck(Arel.sql("customer_id, COUNT(*), SUM(CASE WHEN duration >= 60 THEN 1 ELSE 0 END)"))
                               .each_with_object({}) { |(cid, count, successful), h| h[cid] = { count: count, successful: successful.to_i > 0 } }

    emails_sent_data = Email.where(created_at: date_range, customer_id: all_customer_ids, status: 'sent')
                            .group(:customer_id).count
    emails_received_data = Email.where(created_at: date_range, customer_id: all_customer_ids, status: 'received')
                                .group(:customer_id).count

    wa_sent_data = Message.where(created_at: date_range, customer_id: all_customer_ids, direction: 'outbound')
                          .group(:customer_id).count
    wa_received_data = Message.where(created_at: date_range, customer_id: all_customer_ids, direction: 'inbound')
                              .group(:customer_id).count

    @daily_customer_details = customers.map do |customer|
      rec = recordings_data[customer.id] || { count: 0, successful: false }
      successful_call = rec[:successful]
      message_received = (wa_received_data[customer.id] || 0) > 0
      email_received = (emails_received_data[customer.id] || 0) > 0

      green = successful_call || message_received || email_received

      {
        customer: customer,
        user_name: customer.user&.name || 'Unassigned',
        status: customer.status || 'Pending',
        signal: green ? 'green' : 'red',
        calls_attempted: rec[:count],
        messages_sent: wa_sent_data[customer.id] || 0,
        emails_sent: emails_sent_data[customer.id] || 0
      }
    end.sort_by { |d| [d[:user_name], d[:signal] == 'green' ? 1 : 0] }
  end

  def prepare_customer_status_overview
    user_ids = @users.map(&:id)

    status_counts = Customer.where(user_id: user_ids, created_at: date_range)
                            .group(:user_id, :status).count

    deals_created = Deal.joins(:customer)
                        .where(customers: { user_id: user_ids })
                        .where(deals: { created_at: date_range })
                        .group("customers.user_id").count

    deals_won = Deal.joins(:customer)
                    .where(customers: { user_id: user_ids })
                    .where(deals: { status: 'won', closing_date: @start_date.to_date..@end_date.to_date })
                    .group("customers.user_id").count

    @user_status_overview = @users.map do |user|
      uid = user.id
      {
        user: user,
        pending: status_counts[[uid, 'Pending']] || 0,
        contact_established: status_counts[[uid, 'Contact Established']] || 0,
        contact_not_established: (status_counts[[uid, 'Contact Not Established']] || 0) + (status_counts[[uid, 'Unresponsive']] || 0),
        exhausted: status_counts[[uid, 'Exhausted']] || 0,
        invalid: status_counts[[uid, 'Invalid']] || 0,
        converted: status_counts[[uid, 'Converted']] || 0,
        proposal_sent: status_counts[[uid, 'Proposal Sent']] || 0,
        not_interested: status_counts[[uid, 'Not Interested']] || 0,
        retarget: status_counts[[uid, 'Retarget']] || 0,
        deals_created: deals_created[uid] || 0,
        deals_won: deals_won[uid] || 0
      }
    end
  end
end
