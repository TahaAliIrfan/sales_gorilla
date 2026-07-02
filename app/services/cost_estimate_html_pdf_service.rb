require 'grover'

# Renders a cost estimate proposal as a styled HTML document and converts it
# to PDF using headless Chromium (via Grover/Puppeteer) — same pipeline as
# OdooProposalHtmlPdfService. The HTML template lives at
# app/views/cost_estimates/pdf/proposal.html.erb and owns ALL visual design;
# this service only orchestrates rendering + PDF conversion.
class CostEstimateHtmlPdfService
  TEMPLATE = 'cost_estimates/pdf/proposal'.freeze

  def initialize(cost_estimate)
    @cost_estimate = cost_estimate
  end

  # Returns the PDF as a binary string.
  def generate
    Grover.new(render_html, **grover_options).to_pdf
  end

  # Useful for debugging — returns the raw HTML so you can open it in a browser.
  def render_html
    ApplicationController.renderer.render(
      template: TEMPLATE,
      layout:   false,
      assigns:  { cost_estimate: @cost_estimate }
    )
  end

  private

  def grover_options
    {
      format:                'A4',
      print_background:      true,
      prefer_css_page_size:  true,
      margin: {
        top:    '0mm',
        right:  '0mm',
        bottom: '0mm',
        left:   '0mm'
      },
      timeout:           60_000,
      wait_until:        'networkidle0',
      display_url:       'http://localhost/',
      emulate_media:     'print',
      executable_path:   OdooProposalHtmlPdfService.chrome_executable,
      launch_args:       ['--no-sandbox', '--disable-dev-shm-usage']
    }
  end
end
