# Builds a proposal off a CostEstimate created from the Proposal Generator chat:
# runs the estimate (features + hours), the narrative, renders the report PDF,
# and attaches it. Async because the full chain can take 60-90s — too long for a
# single web request. The chat UI polls #proposal_status until this flips the
# record to "ready" (or "failed").
class GenerateProposalPdfWorker
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 1

  def perform(cost_estimate_id)
    estimate = CostEstimate.find_by(id: cost_estimate_id)
    return unless estimate

    analysis = ClaudeProjectAnalysisService.new.analyze_project(
      app_type: estimate.app_type, description: estimate.description,
      scale: estimate.scale, include_design: estimate.include_design
    )
    raise "estimate analysis failed: #{analysis[:error]}" unless analysis[:success]

    estimate.features = analysis[:features]
    estimate.total_hours = analysis[:total_hours]
    estimate.project_name = estimate.project_name.presence || analysis[:project_name]
    estimate.project_overview = analysis[:project_overview]
    estimate.technical_information_summary = analysis[:technical_information_summary]
    estimate.estimated_timeline_weeks = analysis[:estimated_timeline_weeks]
    estimate.team_composition = analysis[:team_composition]
    estimate.development_methodology = analysis[:development_methodology]
    estimate.key_technology_areas = analysis[:key_technology_areas]
    estimate.save!

    # The two slowest steps — the proposal narrative and the concept mockups —
    # both only need the (now saved) estimate, so run them concurrently. Threads
    # do pure network/CPU work and return data; all DB writes happen below on the
    # main thread (keeps us off the small connection pool).
    narrative = nil
    mockup_pngs = nil
    threads = []
    threads << Thread.new do
      narrative = begin
        CostEstimateAiService.new.generate_project_analysis(estimate)
      rescue => e
        Rails.logger.error("Proposal narrative generation failed: #{e.message}"); nil
      end
    end
    threads << Thread.new do
      mockup_pngs = begin
        MockupGenerationService.new(estimate).generate_pngs
      rescue => e
        Rails.logger.error("Proposal mockup generation failed: #{e.message}"); []
      end
    end
    threads.each(&:join)

    estimate.apply_proposal_content!(narrative)

    Array(mockup_pngs).each_with_index do |(slug, png), i|
      next if png.blank?
      estimate.mockup_images.attach(io: StringIO.new(png), filename: format('%02d-%s.png', i + 1, slug), content_type: 'image/png')
    end

    pdf_binary = begin
      CostEstimateHtmlPdfService.new(estimate).generate
    rescue => e
      Rails.logger.error("HTML PDF generation failed (#{e.message}), falling back to Prawn")
      ProposalGenerationService.new(estimate).generate_pdf.render
    end

    estimate.pdf_file.attach(
      io: StringIO.new(pdf_binary),
      filename: "#{(estimate.app_name.presence || estimate.project_name.presence || 'proposal').parameterize}_proposal.pdf",
      content_type: "application/pdf"
    )
    estimate.update_column(:proposal_state, "ready")
  rescue => e
    Rails.logger.error("GenerateProposalPdfWorker failed for #{cost_estimate_id}: #{e.message}\n#{e.backtrace.first(5).join("\n")}")
    CostEstimate.where(id: cost_estimate_id).update_all(proposal_state: "failed")
    raise
  end
end
