# One turn in an admin's conversation with the CRM-wide AI assistant.
# Unlike CustomerAiChatMessage (scoped to a single customer), these belong to
# the admin user and span the whole CRM. The user's running thread is the set
# of their rows in chronological order.
class AdminAssistantMessage < ApplicationRecord
  belongs_to :user

  ROLES = %w[user assistant].freeze

  validates :role, inclusion: { in: ROLES }
  validates :content, presence: true

  scope :chronological, -> { order(created_at: :asc) }
end
