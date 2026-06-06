require 'grover'

# Renders an Odoo proposal as a styled HTML document and converts it to PDF
# using a headless Chromium (via Grover/Puppeteer). The HTML template lives
# at app/views/odoo_proposals/pdf/proposal.html.erb and owns ALL visual design;
# this service only orchestrates rendering + PDF conversion.
class OdooProposalHtmlPdfService
  TEMPLATE = 'odoo_proposals/pdf/proposal'.freeze

  def initialize(proposal)
    @proposal = proposal
  end

  def generate
    Grover.new(render_html, **grover_options).to_pdf
  end

  # Useful for debugging — returns the raw HTML so you can open it in a browser.
  def render_html
    ApplicationController.renderer.render(
      template: TEMPLATE,
      layout:   false,
      assigns:  { proposal: @proposal }
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
      executable_path:   self.class.chrome_executable,
      launch_args:       ['--no-sandbox', '--disable-dev-shm-usage']
    }
  end

  # Locate a usable system Chrome / Chromium. Looked up lazily so the gem can
  # be deployed in environments where the binary path differs.
  def self.chrome_executable
    candidates = [
      ENV['GROVER_CHROME_PATH'],
      ENV['PUPPETEER_EXECUTABLE_PATH'],
      '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome',
      '/Applications/Chromium.app/Contents/MacOS/Chromium',
      '/usr/bin/google-chrome',
      '/usr/bin/chromium',
      '/usr/bin/chromium-browser'
    ].compact
    candidates.find { |p| File.executable?(p.to_s) }
  end
end
