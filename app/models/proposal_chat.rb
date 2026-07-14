# A persisted Proposal Generator conversation (one per "chat" in the sidebar).
# May be linked to a customer once their data is imported.
class ProposalChat < ApplicationRecord
  belongs_to :user
  belongs_to :customer, optional: true
  has_many :messages, class_name: "ProposalChatMessage", dependent: :destroy

  scope :recent, -> { order(updated_at: :desc) }

  DEFAULT_TITLE = "New proposal".freeze

  def display_title
    title.presence || DEFAULT_TITLE
  end

  # History for the LLM / generation: user + assistant + imported context,
  # chronological. Context rows are folded in as user content so the model
  # "sees" the customer data.
  def llm_history
    messages.order(:created_at).map do |m|
      role = m.role == "assistant" ? "assistant" : "user"
      { "role" => role, "content" => m.content }
    end
  end

  # Set a title from the first real user turn if we don't have one yet.
  def ensure_title_from!(text)
    return if title.present?
    clean = text.to_s.strip.gsub(/\s+/, " ")
    update_column(:title, clean[0, 60].presence || DEFAULT_TITLE)
  end
end
