FactoryGirl.define do
  factory :user do
    sequence(:email) {|n| "email#{n}@example.com" }
    password "foo123"
    sequence(:invitation_token) {|n| "invitation_token_#{n}" }
  end
end