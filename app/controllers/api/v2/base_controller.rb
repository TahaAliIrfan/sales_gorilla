class Api::V2::BaseController < ActionController::API
  include Pundit::Authorization
  
  before_action :authenticate_request
  
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

  def current_user
    @current_user
  end

  def current_user_admin?
    current_user&.admin?
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