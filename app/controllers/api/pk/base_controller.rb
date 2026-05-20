module Api
  module Pk
    class BaseController < ActionController::API
      skip_before_action :verify_authenticity_token, raise: false

      rescue_from ActiveRecord::RecordNotFound, with: :record_not_found
      rescue_from ActiveRecord::RecordInvalid, with: :record_invalid

      private

      def record_not_found
        render json: { success: false, error: 'Record not found' }, status: :not_found
      end

      def record_invalid(exception)
        render json: { success: false, errors: exception.record.errors.full_messages }, status: :unprocessable_entity
      end
    end
  end
end
