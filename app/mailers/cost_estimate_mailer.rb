class CostEstimateMailer < ApplicationMailer
  default from: "calculator@tecaudex.com"

  def send_estimate(cost_estimate, pdf_binary, filename)
    @cost_estimate = cost_estimate
    @customer = cost_estimate.customer

    @app_types = cost_estimate.application_types_array.any? ?
                 cost_estimate.application_types_array.join(', ') :
                 cost_estimate.app_type_display

    attachments[filename] = {
      mime_type: 'application/pdf',
      content: pdf_binary
    }

    mail(
      to: @customer.email,
      subject: "Your Project Proposal from Tecaudex — #{cost_estimate.app_name || 'Cost Estimate'}"
    )
  end
end
