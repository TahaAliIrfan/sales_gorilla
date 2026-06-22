# Renders the per-lead demo story-guide HTML and converts it to a PDF (Grover /
# headless Chromium), mirroring OdooProposalHtmlPdfService.
class DemoGuidePdfService
  TEMPLATE = "demo_guides/guide".freeze

  def self.call(customer) = new(customer).call

  def initialize(customer)
    @customer = customer
  end

  def call
    Grover.new(render_html, format: "A4", print_background: true).to_pdf
  end

  def render_html
    ApplicationController.renderer.render(template: TEMPLATE, layout: false, assigns: { customer: @customer })
  end
end
