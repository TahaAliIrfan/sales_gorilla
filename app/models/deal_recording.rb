class DealRecording < ApplicationRecord
  acts_as_tenant(:organization)

  belongs_to :deal_stage
  belongs_to :deal
  belongs_to :user
end
