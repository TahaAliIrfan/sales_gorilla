FactoryBot.define do
  factory :organization do
    sequence(:name)      { |n| "Org #{n}" }
    sequence(:subdomain) { |n| "org-#{n}" }
    primary_color { "#1E3A8A" }
    accent_color  { "#10B981" }
  end
end
