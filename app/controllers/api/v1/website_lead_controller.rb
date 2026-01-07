module Api
  module V1
    class WebsiteLeadController < Api::V1::BaseController

      def create
        if params[:email].present?
          @customer = Customer.new(name: params[:name],
                                   email: params[:email],
                                   phone: params[:phone],
                                   lead_source: 'Website',
                                   notes: params[:message],
                                   status: params[:]
                                   )
        end
      end

    end
  end
end


create_table "customers", force: :cascade do |t|
  t.string "name"
  t.string "email"
  t.string "phone"
  t.text "address"
  t.string "company"
  t.datetime "created_at", null: false
  t.datetime "updated_at", null: false
  t.text "notes"
  t.bigint "user_id"
  t.string "lead_source", default: ""
  t.string "country_code"
  t.string "linkedin_url"
  t.string "ccr_link"
  t.decimal "project_estimated_cost", precision: 10, scale: 2
  t.string "project_type", default: "Not Applicable"
  t.text "idea_description"