class ReportsController < ApplicationController
  layout "tenant"
  before_action :require_login
  before_action :require_admin_or_manager, only: [:index]

  def index
    setup_date_filters
    setup_kpi_targets

    @users = if current_user.admin?
               User.active_users.where.not(id: User.joins(:roles).where(roles: { name: 'admin' }).select(:id))
             else
               current_user.associates.active_users
             end

    prepare_user_performance
    prepare_customer_status_overview
  end

  def my_reports
    setup_date_filters
    setup_kpi_targets

    @users = [current_user]

    prepare_user_performance
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

  def require_admin_or_manager
    unless current_user&.admin? || current_user&.manager?
      flash[:error] = "You must be an admin or manager to access reports"
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

  def setup_kpi_targets
    days = case @filter_range
           when 'today', 'yesterday' then 1
           when 'last_week' then 7
           when 'month' then ((@end_date.to_date - @start_date.to_date).to_i + 1)
           when 'custom' then ((@end_date.to_date - @start_date.to_date).to_i + 1)
           else 1
           end

    @kpi_targets = {
      calls_attempted: 10 * days,
      connected_calls: 3 * days,
      whatsapp_messages_sent: 10 * days,
      emails_sent: 10 * days
    }
  end

  def date_range
    @start_date..@end_date
  end

  def prepare_user_performance
    user_ids = @users.map(&:id)

    customer_scope = Customer.where(user_id: user_ids, created_at: date_range)
    leads_by_user = customer_scope.group(:user_id).count

    kpi_totals = UserKpiRecord.totals_for_users(user_ids, @start_date, @end_date)

    customer_ids_in_scope = customer_scope.pluck(:id, :user_id)
    cid_to_uid = customer_ids_in_scope.each_with_object({}) { |(cid, uid), h| h[cid] = uid }

    inbound_by_customer = Message.where(customer_id: cid_to_uid.keys, direction: 'inbound')
                                 .group(:customer_id).count
    whatsapp_replies_by_user = inbound_by_customer.each_with_object({}) do |(cid, count), h|
      uid = cid_to_uid[cid]
      h[uid] = (h[uid] || 0) + count
    end

    deals_by_user = Deal.where(user_id: user_ids, created_at: date_range)
                        .group(:user_id).count

    @user_performance = @users.map do |user|
      kpi = kpi_totals[user.id]
      {
        user: user,
        leads_assigned: leads_by_user[user.id] || 0,
        calls_attempted: kpi&.total_calls_attempted.to_i,
        connected_calls: kpi&.total_connected_calls.to_i,
        emails_sent: kpi&.total_emails_sent.to_i,
        whatsapp_sent: kpi&.total_whatsapp_messages_sent.to_i,
        whatsapp_replies: whatsapp_replies_by_user[user.id] || 0,
        deals: deals_by_user[user.id] || 0
      }
    end
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
