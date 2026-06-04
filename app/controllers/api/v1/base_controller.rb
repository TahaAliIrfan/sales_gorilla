class Api::V1::BaseController < ActionController::API
  rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
  rescue_from ActiveRecord::RecordInvalid, with: :record_invalid

  private

  def record_not_found(exception)
    render json: { error: "Record not found" }, status: :not_found
  end

  def record_invalid(exception)
    render json: {
      error: "Validation failed",
      details: exception.record.errors.full_messages
    }, status: :unprocessable_entity
  end

  def render_success(data = nil, message = "Success", status = :ok)
    response = { success: true, message: message }
    response[:data] = data if data
    render json: response, status: status
  end

  def render_error(message = "Error", details = nil, status = :bad_request)
    response = { success: false, error: message }
    response[:details] = details if details
    render json: response, status: status
  end
end
