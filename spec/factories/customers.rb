FactoryBot.define do
  factory :customer do
    sequence(:name) { |n| "Customer #{n}" }
    organization { ActsAsTenant.current_tenant || association(:organization) }
  end
end
