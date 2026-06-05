require "grover"

# Renders an Email (subject, headers, body, attachments list, open-tracking
# state) as a styled HTML document, then converts it to PDF via headless
# Chromium (Grover/Puppeteer). The HTML template lives at
# app/views/emails/pdf/show.html.erb — this service only orchestrates render +
# PDF conversion.
class EmailPdfService
  TEMPLATE = "emails/pdf/show".freeze

  def initialize(email)
    @email = email
  end

  def generate
    Grover.new(render_html, **grover_options).to_pdf
  end

  # Useful for debugging — open the raw HTML in a browser to tweak the layout
  # without paying for a PDF render on every iteration.
  def render_html
    ApplicationController.renderer.render(
      template: TEMPLATE,
      layout:   false,
      assigns:  { email: @email }
    )
  end

  private

  def grover_options
    {
      format:                "A4",
      print_background:      true,
      prefer_css_page_size:  true,
      margin: {
        top:    "16mm",
        right:  "14mm",
        bottom: "16mm",
        left:   "14mm"
      },
      timeout:           60_000,
      wait_until:        "networkidle0",
      display_url:       "http://localhost/",
      emulate_media:     "print",
      executable_path:   self.class.chrome_executable,
      launch_args:       [ "--no-sandbox", "--disable-dev-shm-usage" ]
    }
  end

  # Re-use the same Chrome locator that OdooProposalHtmlPdfService uses so we
  # don't drift across environments.
  def self.chrome_executable
    candidates = [
      ENV["GROVER_CHROME_PATH"],
      ENV["PUPPETEER_EXECUTABLE_PATH"],
      "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
      "/Applications/Chromium.app/Contents/MacOS/Chromium",
      "/usr/bin/google-chrome",
      "/usr/bin/chromium",
      "/usr/bin/chromium-browser"
    ].compact
    candidates.find { |p| File.executable?(p.to_s) }
  end
end
