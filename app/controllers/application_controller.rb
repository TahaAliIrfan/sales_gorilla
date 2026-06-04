class ApplicationController < ActionController::Base
  include SetsCurrentTenant
  include Pundit::Authorization

  helper_method :current_user, :current_user_admin?, :current_organization, :current_membership, :current_user_in_org?

  # Rescue from common exceptions
  rescue_from ActiveRecord::RecordInvalid, with: :handle_validation_error
  rescue_from ActiveRecord::RecordNotFound, with: :handle_record_not_found
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  # When a request comes in on a tenant subdomain, require a logged-in user
  # and a membership in the corresponding organization. Marketing/auth/org-
  # management on the root domain skip this.
  before_action :authorize_tenant_request!, if: :tenant_request?

  before_action :set_tasks_notification_counts, if: :current_user_in_org?
  before_action :set_notification_counts, if: :current_user_in_org?

  private

  # These counters touch tenant-scoped tables, so only run them when the
  # request is inside an organization (i.e. on a tenant subdomain).
  def current_user_in_org?
    current_user.present? && current_organization.present?
  end

  # True when the request came in on an organization subdomain (e.g. acme.).
  def tenant_request?
    tenant_subdomain.present?
  end

  def authorize_tenant_request!
    if current_organization.blank?
      raise ActiveRecord::RecordNotFound, "No organization for subdomain #{request.subdomain.inspect}"
    end
    unless current_user
      flash[:error] = "Please sign in to continue."
      return redirect_to_root_signin
    end
    unless current_membership
      flash[:error] = "You don't have access to this organization."
      redirect_to root_url(subdomain: nil, host: root_host), allow_other_host: true
    end
  end

  def set_tasks_notification_counts
    @pending_tasks_count = Task.where(user_id: current_user.id, status: "pending").count

    @urgent_tasks_count = Task.where(user_id: current_user.id)
                              .where("(status = 'pending' AND due_date < ?) OR (status = 'pending' AND priority = 'high')",
                                     Date.current)
                              .count
  end

  def set_notification_counts
    @unread_notifications_count = current_user.unread_notifications_count
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def current_user_admin?
    current_user&.admin?
  end

  def current_membership
    return @current_membership if defined?(@current_membership)
    @current_membership = if current_user && current_organization
                            current_user.membership_for(current_organization)
    end
  end

  def pundit_user
    UserContext.new(user: current_user, organization: current_organization, membership: current_membership)
  end

  def require_login
    unless current_user
      respond_to do |format|
        format.html do
          flash[:error] = "You must be logged in to access this section"
          redirect_to_root_signin
        end
        format.json { render json: { error: "Authentication required" }, status: :unauthorized }
      end
    end
  end

  def require_admin
    unless current_user_admin?
      flash[:error] = "You don't have permission to access this section"
      redirect_to customers_path
    end
  end

  def handle_validation_error(exception)
    Rails.logger.error("Validation error: #{exception.message}")
    flash[:error] = "Validation error: #{exception.message}"
    redirect_back(fallback_location: safe_root_path)
  end

  def handle_record_not_found(exception)
    Rails.logger.error("Record not found: #{exception.message}")
    flash[:error] = "The requested record could not be found."
    redirect_to safe_root_path
  end

  def user_not_authorized(exception)
    respond_to do |format|
      format.html do
        flash[:error] = "You are not authorized to perform this action."
        redirect_to(request.referrer || safe_root_path)
      end
      format.json { render json: { error: "Not authorized" }, status: :forbidden }
    end
  end

  # Tenant routes don't exist on the root domain; fall back to marketing root.
  def safe_root_path
    current_organization ? tenant_root_path : root_path
  end

  # Push the visitor to the bare-domain sign-in screen.
  def redirect_to_root_signin
    redirect_to root_url(subdomain: nil, host: root_host), allow_other_host: true
  end

  # Strip any subdomain to produce the bare host (used for cross-host redirects).
  def root_host
    request.host.split(".").drop_while { |part| part != "tecaudex" && !part.match?(/\A\d+\z/) }.join(".").presence || request.host
  end
end
