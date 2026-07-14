class AddKindToProposalChatsAndStateToOdoo < ActiveRecord::Migration[7.1]
  def change
    # "cost" (Proposal Generator) | "odoo" (Odoo proposal) — same chat UI/infra.
    add_column :proposal_chats, :kind, :string, null: false, default: "cost"
    # async generation state for the chat-driven Odoo proposal build.
    add_column :odoo_proposals, :proposal_state, :string
  end
end
