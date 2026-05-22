class BuyerPersonaResearchWorker
  include Sidekiq::Worker
  sidekiq_options queue: 'default', retry: 2

  def perform(customer_id)
    customer = Customer.find_by(id: customer_id)
    return unless customer

    persona = customer.buyer_persona_research ||
              customer.create_buyer_persona_research(status: 'processing')

    persona.update!(status: 'processing')

    result = BuyerPersonaResearchService.new(customer).research

    if result[:success]
      persona.update!(
        status:                  'completed',
        professional_background: result[:professional_background],
        industry_analysis:       result[:industry_analysis],
        pain_points:             result[:pain_points],
        budget_indicators:       result[:budget_indicators],
        communication_style:     result[:communication_style],
        recommended_approach:    result[:recommended_approach],
        key_insights:            result[:key_insights],
        persona_summary:         result[:persona_summary],
        confidence_score:        result[:confidence_score],
        raw_response:            result[:raw_response],
        researched_at:           Time.current
      )

      admin_role = Role.find_by(key: 'admin')
      system_user = admin_role ? User.joins(:role_assignments).where(role_assignments: { role_id: admin_role.id }).first : nil
      if system_user
        customer.customer_activities.create!(
          action:  'Buyer Persona Research',
          details: "AI buyer persona research completed. Confidence: #{result[:confidence_score]}%",
          user_id: system_user.id
        )
      end
    else
      persona.update!(status: 'failed')
      Rails.logger.error "BuyerPersonaResearchWorker failed for customer #{customer_id}: #{result[:error]}"
    end
  end
end
