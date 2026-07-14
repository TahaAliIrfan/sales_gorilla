class AddProposalStateToCostEstimates < ActiveRecord::Migration[7.1]
  def change
    # Tracks the async proposal build kicked off from the chat:
    # nil (legacy/synchronous) | "generating" | "ready" | "failed".
    add_column :cost_estimates, :proposal_state, :string
  end
end
