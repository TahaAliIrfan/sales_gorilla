class Api::V2::BaseController < ActionController::API
  include Pundit::Authorization

  before_action :authenticate_request
  before_action :resolve_current_tenant

  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :record_invalid
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized
  rescue_from JWT::DecodeError, with: :invalid_token

  private

  def authenticate_request
    header = request.headers['Authorization']
    header = header.split(' ').last if header

    begin
      @decoded = JsonWebToken.decode(header)
      @current_user = User.find(@decoded[:user_id])
    rescue ActiveRecord::RecordNotFound => e
      Rails.logger.error "JWT Authentication failed - User not found: #{e.message}"
      render json: { error: 'Invalid token' }, status: :unauthorized
    rescue JWT::DecodeError => e
      Rails.logger.error "JWT Authentication failed - JWT decode error: #{e.message}"
      render json: { error: 'Invalid token' }, status: :unauthorized
    rescue => e
      Rails.logger.error "JWT Authentication failed - General error: #{e.message}"
      render json: { error: 'Invalid token' }, status: :unauthorized
    end
  end

  # Pick the tenant for this request, in priority order:
  #   1. JWT claim `organization_id` (preferred — set when mobile picks an org)
  #   2. Header `X-Organization-Subdomain` (lets a client override per-request)
  #   3. User's first membership (back-compat for existing mobile tokens that
  #      were issued before multi-tenancy and have no org claim)
  #
  # If the resolved org exists but the user isn't a member, reject with 403.
  # Endpoints that don't need a tenant (login, listing the user's orgs) can
  # skip this with `skip_before_action :resolve_current_tenant`.
  # Priority order, with strict rejection:
  #   1. JWT claim `organization_id` — if set but invalid / not a member, 403.
  #   2. Header `X-Organization-Subdomain` — same: if set but invalid, 403.
  #   3. Default to the user's first org (back-compat for tokens minted before
  #      multi-tenancy and missing the org claim).
  def resolve_current_tenant
    return unless @current_user

    if (jwt_org_id = @decoded && @decoded[:organization_id]).present?
      org = Organization.find_by(id: jwt_org_id)
      return render_error('Token references an unknown organization', nil, :forbidden) if org.nil?
      return assign_tenant(org)
    end

    if (header_subdomain = request.headers['X-Organization-Subdomain'].to_s.strip.downcase).present?
      org = Organization.find_by(subdomain: header_subdomain)
      return render_error("Organization '#{header_subdomain}' not found", nil, :forbidden) if org.nil?
      return assign_tenant(org)
    end

    org = @current_user.organizations.order(:created_at).first
    return render_error('No organization available for this user', nil, :forbidden) if org.nil?
    assign_tenant(org)
  end

  def assign_tenant(org)
    unless @current_user.member_of?(org)
      return render_error("Not a member of organization '#{org.subdomain}'", nil, :forbidden)
    end

    @current_organization = org
    @current_membership   = @current_user.membership_for(org)
    ActsAsTenant.current_tenant = org
  end

  def current_user
    @current_user
  end

  def current_user_admin?
    current_user&.admin?
  end

  def current_organization
    @current_organization
  end

  def current_membership
    @current_membership
  end

  def pundit_user
    UserContext.new(user: current_user, organization: current_organization, membership: current_membership)
  end

  def record_not_found(exception)
    render json: { error: 'Record not found' }, status: :not_found
  end

  def record_invalid(exception)
    render json: {
      error: 'Validation failed',
      details: exception.record.errors.full_messages
    }, status: :unprocessable_entity
  end

  def user_not_authorized
    render json: { error: 'Not authorized' }, status: :forbidden
  end

  def invalid_token
    render json: { error: 'Invalid token' }, status: :unauthorized
  end

  def render_success(data = nil, message = 'Success', status = :ok)
    response = { success: true, message: message }
    response[:data] = data if data
    render json: response, status: status
  end

  def render_error(message = 'Error', details = nil, status = :bad_request)
    response = { success: false, error: message }
    response[:details] = details if details
    render json: response, status: status
  end
end
