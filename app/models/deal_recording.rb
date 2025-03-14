class DealRecording < ApplicationRecord
  belongs_to :deal_stage
  belongs_to :deal
  belongs_to :user
end