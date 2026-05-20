module Api
  module Pk
    class WebsiteLeadsController < Api::Pk::BaseController

      def create
        if params[:email].blank? && params[:phone].blank?
          render json: { success: false, error: 'Email or phone is required' }, status: :unprocessable_entity
          return
        end

        if params[:email].present?
          existing = Customer.find_by(email: params[:email])
          if existing
            existing.update!(updated_at: Time.current, repeat_lead: true)
            render json: { success: true, message: 'Lead already exists, marked as repeat' }, status: :ok
            return
          end
        end

        customer = Customer.new(
          name: params[:name],
          email: params[:email],
          phone: params[:phone],
          idea_description: params[:message],
          lead_source: 'ODOO_PK',
          status: 'Pending'
        )

        if customer.save
          render json: { success: true, message: 'Lead created successfully' }, status: :created
        else
          render json: { success: false, errors: customer.errors.full_messages }, status: :unprocessable_entity
        end
      end

    end
  end
end
