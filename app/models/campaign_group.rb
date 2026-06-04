class CampaignGroup < ApplicationRecord
  acts_as_tenant(:organization)

  belongs_to :campaign
  belongs_to :customer_group
end
