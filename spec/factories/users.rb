FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:name)  { |n| "User #{n}" }
    provider { "google_oauth2" }
    sequence(:uid)   { |n| "uid-#{n}" }
    active { true }
  end
end
