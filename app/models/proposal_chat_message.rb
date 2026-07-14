class ProposalChatMessage < ApplicationRecord
  belongs_to :proposal_chat, touch: true # bumps chat.updated_at so recent order works

  ROLES = %w[user assistant context].freeze

  validates :role, inclusion: { in: ROLES }
  validates :content, presence: true

  scope :chronological, -> { order(created_at: :asc) }

  # context rows carry imported customer data; the UI renders them as a chip.
  def context?
    role == "context"
  end
end
