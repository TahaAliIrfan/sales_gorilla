module Api
  module V1
    class WebsiteLeadController < Api::V1::BaseController

      def create
        if params[:email].present?
          @customer = Customer.new(name: params[:name],
                                   email: params[:email],
                                   phone: params[:phone_number],
                                   lead_source: 'Website',
                                   utm_campaign: params[:utm_campaign],
                                   utm_term: params[:utm_term],
                                   notes: params[:message])
          if @customer.save
            render json: { success: true, message: "Successfully created" }, status: :created
          end
        else
          render json: { success: false, errors: "Unable to add" }, status: :unprocessable_entity
        end
      end

    end
  end
end