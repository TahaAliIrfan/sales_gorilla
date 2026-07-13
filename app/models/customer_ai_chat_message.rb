# One turn of a customer's AI chat thread (see CustomerAiChatService).
# The thread is scoped to the customer and shared across reps; `user` records
# who sent each message. `role` is "user" or "assistant".
class CustomerAiChatMessage < ApplicationRecord
  belongs_to :customer
  belongs_to :user, optional: true

  ROLES = %w[user assistant].freeze

  validates :role, inclusion: { in: ROLES }
  validates :content, presence: true

  scope :chronological, -> { order(:created_at) }
end
