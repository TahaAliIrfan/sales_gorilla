FactoryBot.define do
  factory :membership do
    user
    organization
    role { "admin" }

    trait :owner  do role { "owner"  } end
    trait :admin  do role { "admin"  } end
    trait :member do role { "member" } end
    trait :viewer do role { "viewer" } end
  end
end
