class SendCostEstimatePdfJob
  include Sidekiq::Job

  sidekiq_options queue: :notifications, retry: 3

  def perform(cost_estimate_id)
    cost_estimate = CostEstimate.find_by(id: cost_estimate_id)

    unless cost_estimate
      Rails.logger.error("SendCostEstimatePdfJob: CostEstimate #{cost_estimate_id} not found")
      return
    end

    customer = cost_estimate.customer

    unless customer&.phone.present?
      Rails.logger.warn("SendCostEstimatePdfJob: Customer #{customer&.id} has no phone number")
      return
    end

    already_sent_whatsapp = cost_estimate.pdf_file.attached?

    if already_sent_whatsapp
      Rails.logger.info("SendCostEstimatePdfJob: PDF already attached for estimate #{cost_estimate_id}, skipping WhatsApp (retry scenario)")
    end

    begin
      # Generate AI content if not already present
      if cost_estimate.app_name.blank?
        Rails.logger.info("Generating AI content for cost estimate #{cost_estimate_id}")
        ai_service = CostEstimateAiService.new

        analysis = ai_service.generate_project_analysis(cost_estimate)
        if analysis
          cost_estimate.update!(
            app_name: analysis['app_name'],
            similar_apps: analysis['similar_apps'].to_json,
            technical_information_summary: analysis['technical_info'].to_json,
            executive_summary: analysis['executive_summary'].to_json,
            feature_prioritization: analysis['feature_prioritization'].to_json
          )
          Rails.logger.info("Generated app name: #{analysis['app_name']}")
          Rails.logger.info("Generated technical information")
          Rails.logger.info("Generated executive summary")
          Rails.logger.info("Generated feature prioritization")
        else
          cost_estimate.update!(
            app_name: "#{customer.name}'s App",
            similar_apps: [].to_json
          )
          Rails.logger.warn("AI analysis failed, using fallback app name")
        end
      end

      # Generate the PDF
      Rails.logger.info("Generating PDF for cost estimate #{cost_estimate_id}")
      proposal_service = ProposalGenerationService.new(cost_estimate)
      pdf = proposal_service.generate_pdf
      pdf_binary = pdf.render.force_encoding('BINARY')
      pdf_content = Base64.strict_encode64(pdf_binary)

      app_name_clean = cost_estimate.app_name.present? ? cost_estimate.app_name.gsub(/\s+/, '_') : customer.name.gsub(/\s+/, '_')
      filename = "Project_Proposal_#{app_name_clean}_#{Date.current.strftime('%Y%m%d')}.pdf"

      # Only send WhatsApp if not already sent (prevents duplicate messages on retry)
      whatsapp_success = false
      unless already_sent_whatsapp
        whatsapp_service = Whatsapp::ApiService.new
        chat_id = whatsapp_service.get_whatsapp_chat_id(customer.phone)

        app_types = cost_estimate.application_types_array.any? ?
                    cost_estimate.application_types_array.join(', ').upcase :
                    cost_estimate.app_type_display

        caption = "Hi #{customer.name}! 👋\n\n" \
                  "Thank you for your interest in building with us! Here's your detailed cost estimate.\n\n" \
                  "📱 Project Type: #{app_types}\n" \
                  "📊 Scale: #{cost_estimate.scale.titleize}\n" \
                  "⏱️ Total Hours: #{cost_estimate.total_hours}\n" \
                  "💰 Total Cost: $#{number_with_commas(cost_estimate.total_cost.to_i)}\n\n" \
                  "Please review the attached PDF for complete details. Feel free to reach out if you have any questions!\n\n" \
                  "Best regards,\nTecaudex Team"

        Rails.logger.info("SendCostEstimatePdfJob: Sending PDF to chat_id: #{chat_id}, filename: #{filename}, pdf_size: #{pdf_binary.bytesize} bytes")

        response = whatsapp_service.send_file(
          chat_id,
          pdf_content,
          filename,
          caption,
          'application/pdf'
        )

        Rails.logger.info("SendCostEstimatePdfJob: WhatsApp API response: #{response.inspect}")
        whatsapp_success = response[:success]

        unless whatsapp_success
          Rails.logger.error("Failed to send PDF via WhatsApp: #{response[:error]}")
          raise "WhatsApp API Error: #{response[:error]}"
        end

        Rails.logger.info("Successfully sent PDF to customer #{customer.id} via WhatsApp")
      else
        whatsapp_success = true
      end

      # Attach PDF to Active Storage (acts as idempotency marker for WhatsApp)
      unless cost_estimate.pdf_file.attached?
        cost_estimate.pdf_file.attach(
          io: StringIO.new(pdf_binary),
          filename: filename,
          content_type: 'application/pdf'
        )
        Rails.logger.info("PDF saved to Active Storage: #{filename}")
      end

      # Store public URL — non-critical, don't let it fail the job
      if cost_estimate.pdf_file.attached? && cost_estimate.pdf_url.blank?
        begin
          url_options = Rails.application.config.action_mailer.default_url_options || { host: 'localhost', port: 3000 }
          cost_estimate.update_column(:pdf_url, Rails.application.routes.url_helpers.rails_blob_url(cost_estimate.pdf_file, **url_options))
        rescue => e
          Rails.logger.warn("Could not generate PDF URL: #{e.message}")
        end
      end

      # Send via Email — isolated so failures don't trigger WhatsApp re-send
      email_sent = false
      if customer.email.present?
        begin
          Rails.logger.info("SendCostEstimatePdfJob: Sending PDF via email to #{customer.email}")
          CostEstimateMailer.send_estimate(cost_estimate, pdf_binary, filename).deliver_now
          Rails.logger.info("Successfully sent PDF to customer #{customer.id} via Email")
          email_sent = true
        rescue => e
          Rails.logger.error("SendCostEstimatePdfJob: Email delivery failed for customer #{customer.id}: #{e.message}")
          Rails.logger.error(e.backtrace.first(5).join("\n"))
        end
      else
        Rails.logger.warn("SendCostEstimatePdfJob: Customer #{customer.id} has no email address, skipping email")
      end


    rescue => e
      Rails.logger.error("Error in SendCostEstimatePdfJob: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      raise e
    end
  end

  private

  def number_with_commas(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end
