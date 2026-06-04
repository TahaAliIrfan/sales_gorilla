class CampaignGroup < ApplicationRecord
  belongs_to :campaign
  belongs_to :customer_group
end
