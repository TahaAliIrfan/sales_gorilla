# Generates the AI narrative for a chat-built Odoo proposal (async, since the
# gpt-5.5 call can take ~30-40s). The proposal + pricing are created
# synchronously in the controller; this fills the narrative and flips the
# record to "ready". The chat polls #proposal_status.
class GenerateOdooProposalWorker
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 1

  def perform(odoo_proposal_id)
    proposal = OdooProposal.find_by(id: odoo_proposal_id)
    return unless proposal

    result = OdooProposalNarrativeService.new(proposal).generate_all
    if result
      proposal.update(
        claude_summary: result['summary'],
        claude_rationale: result['rationale'],
        claude_module_justifications: result['module_justifications'],
        claude_next_steps: result['next_steps'],
        narrative_generated_at: Time.current
      )
    else
      Rails.logger.warn("GenerateOdooProposalWorker: narrative failed for #{odoo_proposal_id}, continuing")
    end

    proposal.update_column(:proposal_state, "ready")
  rescue => e
    Rails.logger.error("GenerateOdooProposalWorker failed for #{odoo_proposal_id}: #{e.message}")
    OdooProposal.where(id: odoo_proposal_id).update_all(proposal_state: "failed")
    raise
  end
end
