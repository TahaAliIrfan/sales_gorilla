FactoryBot.define do
  factory :partner_portal_lead do
    organization
    sequence(:portal_lead_id) { |n| "lead-#{n}" }
    status { "received" }
    raw_payload { { "title" => "Some Lead" } }
  end
end
