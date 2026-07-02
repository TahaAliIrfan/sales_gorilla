require 'net/http'
require 'json'
require 'base64'
require 'grover'

# Generates concept screens for a cost estimate and attaches them to the
# estimate as `mockup_images`, so the proposal PDF can embed them in the
# Design Concepts section.
#
# Primary pipeline (Claude + headless Chrome):
#   1. Claude Sonnet authors TWO complete standalone HTML screens in one call,
#      sharing a single design system, so both look like screens of one app.
#   2. Headless Chromium (Grover — same binary the PDF pipeline uses) renders
#      each document at device resolution and screenshots it to PNG.
#   Real HTML means pixel-crisp type and true design-system spacing — a
#   screenshot of rendered UI, not an AI painting of one.
#
# Fallback pipeline (Gemini image models) is kept for resilience: if Claude
# or Chrome fails, we fall back to Nano Banana image generation.
#
# Idempotent — skips generation if images are already attached.
class MockupGenerationService
  CLAUDE_MODEL   = 'claude-sonnet-4-6'.freeze
  SCREEN_BREAK   = '<<<SCREEN_BREAK>>>'.freeze
  ANTHROPIC_URL  = 'https://api.anthropic.com/v1/messages'.freeze

  PRIMARY_MODEL  = 'gemini-3-pro-image-preview'.freeze  # fallback: Nano Banana Pro
  FALLBACK_MODEL = 'gemini-2.5-flash-image'.freeze      # fallback: original Nano Banana
  RESEARCH_MODEL = 'gemini-2.5-flash'.freeze            # fallback: design-brief research
  ENDPOINT = 'https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent'.freeze

  # Rendered viewport per platform (deviceScaleFactor 2 for retina crispness)
  MOBILE_VIEWPORT = { width: 390,  height: 844 }.freeze
  WEB_VIEWPORT    = { width: 1440, height: 810 }.freeze

  DEFAULT_BRIEF = {
    'design_system'   => 'Material Design 3',
    'primary_color'   => '#2563EB',
    'accent_color'    => '#F59E0B',
    'background'      => 'white with soft neutral surfaces and subtle elevation',
    'typography'      => 'clean geometric sans-serif, strong numerals',
    'mood'            => 'modern, trustworthy, focused',
    'key_ui_patterns' => []
  }.freeze

  def initialize(cost_estimate)
    @cost_estimate = cost_estimate
    @anthropic_key = Rails.application.credentials.dig(:ANTHROPIC_API_KEY) || ENV['ANTHROPIC_API_KEY']
    @api_key = Rails.application.credentials.dig(:GOOGLE_STUDIO_API_KEY) || ENV['GOOGLE_STUDIO_API_KEY']
  end

  # Returns true if at least one mockup ends up attached.
  def generate_and_attach
    return true if @cost_estimate.mockup_images.attached?
    raise 'cost estimate must be persisted to attach mockups' unless @cost_estimate.persisted?

    screens = claude_screens
    if screens.present?
      attached = attach_screens(screens) { |html| render_screenshot(html) }
      return true if attached.positive?
      Rails.logger.warn('MockupGenerationService: Claude pipeline produced no renderable screens, falling back to image models')
    end

    gemini_fallback
  end

  private

  def app_name
    @cost_estimate.app_name.presence || @cost_estimate.project_name.presence || 'the app'
  end

  def top_features
    @cost_estimate.features
                  .sort_by { |f| -f['hours'].to_i }
                  .map { |f| f['name'].to_s }
                  .reject(&:blank?)
  end

  def key_feature
    top_features.first.presence || 'the core feature'
  end

  def mobile?
    @cost_estimate.mobile_app?
  end

  def viewport
    mobile? ? MOBILE_VIEWPORT : WEB_VIEWPORT
  end

  # ── Primary pipeline: Claude writes the UI, Chrome photographs it ──────

  # Returns [[slug, html], [slug, html]] (home first) or nil on failure.
  def claude_screens
    if @anthropic_key.blank?
      Rails.logger.warn('MockupGenerationService: ANTHROPIC_API_KEY not configured, skipping Claude pipeline')
      return nil
    end

    raw = request_claude(screens_prompt)
    return nil if raw.blank?

    docs = raw.split(SCREEN_BREAK).map(&:strip).reject(&:blank?)
    docs = docs.map { |d| d.sub(/\A```html?\s*/i, '').sub(/```\z/, '').strip }
    docs = docs.select { |d| d.match?(/<html/i) && d.match?(/<\/html>/i) }

    unless docs.size == 2
      Rails.logger.warn("MockupGenerationService: expected 2 HTML screens from Claude, got #{docs.size}")
      return nil
    end

    [
      ['home-screen', docs[0]],
      [key_feature.parameterize.presence || 'key-feature', docs[1]]
    ]
  end

  def screens_prompt
    similar  = @cost_estimate.similar_apps_data.map { |a| a['name'] }.compact.first(5)
    features = top_features
    vp       = viewport
    surface  = mobile? ? "mobile app (viewport exactly #{vp[:width]}x#{vp[:height]})" :
                         "desktop web application (viewport exactly #{vp[:width]}x#{vp[:height]})"

    <<~PROMPT
      You are a senior product designer at a top design studio, producing two pixel-perfect
      UI mockup screens for a client pitch deck. These will be screenshotted at exact
      viewport size and printed in a proposal document, so they must look like polished
      Figma exports — calm, confident, unmistakably designed by a human expert.

      Product: "#{app_name}"
      Description: #{@cost_estimate.description.to_s.truncate(400)}
      Platform: #{surface}
      Key features: #{features.first(6).join(', ')}
      Comparable products: #{similar.join(', ').presence || 'none identified'}

      First, silently decide a design direction for THIS domain: a custom colour palette
      suited to its audience psychology (never generic blue, never red #ED1A3B), one
      Google Fonts pairing, and the right design language
      (#{mobile? ? 'iOS HIG or Material 3' : 'modern SaaS web'}).

      Then output TWO complete standalone HTML documents:

      SCREEN 1 — the home screen a signed-in user sees. Exactly: a short personal
      greeting, ONE hero card for the primary action (#{features.first.presence || 'the main feature'}),
      one or two small supporting cards, #{mobile? ? 'a slim iOS status bar at the top and a bottom tab bar with 4 icons' : 'a compact left sidebar or top navigation'}.
      A calm, breathable daily view — not a dashboard of every feature.

      SCREEN 2 — the "#{key_feature}" screen, showing just that single flow in a
      spacious, focused layout with a small amount of believable example data.

      Hard rules:
      - Both screens share the EXACT same design system — palette, fonts, radii,
        spacing, iconography — as two artboards of one Figma file.
      - html,body: margin 0; width #{vp[:width]}px; height #{vp[:height]}px; overflow hidden.
        Content must fit the viewport exactly — nothing may overflow or scroll.
      - Composition: generous white space on an 8px grid, one clear focal point per
        screen, at most 4 components, strong type hierarchy, labels of 1-3 words,
        realistic believable content (names, numbers, dates).
      - No dense tables, no long lists (3 items max), no tiny paragraph text,
        at most one simple chart (pure CSS/SVG).
      - Fully self-contained: one inline <style> block, no external images, no
        JavaScript, no CDN libraries. Google Fonts via @import is allowed.
        Icons must be inline SVG (simple 24px stroke icons). Avatars are initials
        in coloured circles. Photos are CSS gradient placeholders.
      - Subtle depth: soft shadows, gentle rounded corners; never harsh borders.

      Output format: the first HTML document, then a line containing exactly
      #{SCREEN_BREAK}
      then the second HTML document. No markdown fences, no commentary, nothing else.
    PROMPT
  end

  def request_claude(prompt)
    uri = URI(ANTHROPIC_URL)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 15
    http.read_timeout = 300

    request = Net::HTTP::Post.new(uri.path, {
      'Content-Type'      => 'application/json',
      'x-api-key'         => @anthropic_key,
      'anthropic-version' => '2023-06-01'
    })
    request.body = {
      model: CLAUDE_MODEL,
      max_tokens: 20_000,
      messages: [{ role: 'user', content: prompt }]
    }.to_json

    response = http.request(request)
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.warn("MockupGenerationService: Claude returned #{response.code}: #{response.body.to_s.truncate(300)}")
      return nil
    end

    JSON.parse(response.body).dig('content', 0, 'text')
  rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
    Rails.logger.warn("MockupGenerationService: Claude request failed: #{e.class} #{e.message}")
    nil
  end

  # Screenshot a standalone HTML document at device resolution.
  def render_screenshot(html)
    vp = viewport
    Grover.new(
      html,
      viewport: { width: vp[:width], height: vp[:height], deviceScaleFactor: 2 },
      full_page: false,
      wait_until: 'networkidle0',
      timeout: 60_000,
      executable_path: OdooProposalHtmlPdfService.chrome_executable,
      launch_args: ['--no-sandbox', '--disable-dev-shm-usage']
    ).to_png
  rescue => e
    Rails.logger.warn("MockupGenerationService: screenshot render failed: #{e.class} #{e.message}")
    nil
  end

  # Shared attach loop — yields each screen's payload to the renderer.
  def attach_screens(screens)
    attached = 0
    screens.each_with_index do |(slug, payload), i|
      png = yield(payload)
      if png.blank?
        Rails.logger.warn("MockupGenerationService: no image for screen '#{slug}'")
        next
      end

      @cost_estimate.mockup_images.attach(
        io: StringIO.new(png),
        filename: format('%02d-%s.png', i + 1, slug),
        content_type: 'image/png'
      )
      attached += 1
      Rails.logger.info("MockupGenerationService: attached mockup #{i + 1} (#{slug}, #{png.bytesize} bytes)")
    end
    attached
  end

  # ── Fallback pipeline: Gemini image models (Nano Banana) ───────────────

  def gemini_fallback
    if @api_key.blank?
      Rails.logger.warn('MockupGenerationService: GOOGLE_STUDIO_API_KEY not configured, skipping fallback mockups')
      return false
    end

    brief = design_brief
    Rails.logger.info("MockupGenerationService: fallback design brief — #{brief['design_system']}, primary #{brief['primary_color']}")

    home_spec, feature_spec = screen_specs(brief)

    # The single-flow feature screen renders most reliably, so generate it
    # first and feed it back as a style reference for the home screen.
    feature_png = generate_image(feature_spec[:prompt])
    home_png    = generate_image(home_spec[:prompt], reference: feature_png)

    screens = [
      [home_spec[:slug],    home_png],
      [feature_spec[:slug], feature_png]
    ]
    attach_screens(screens) { |png| png }.positive?
  end

  # Asks a Gemini text model to act as a product designer and return a design
  # brief tailored to this app's domain. Falls back to DEFAULT_BRIEF on any
  # failure so image generation always has a usable direction.
  def design_brief
    raw = request_text(RESEARCH_MODEL, research_prompt)
    parsed = raw.present? ? JSON.parse(raw) : {}
    parsed = {} unless parsed.is_a?(Hash)

    brief = DEFAULT_BRIEF.merge(parsed.slice(*DEFAULT_BRIEF.keys))
    brief['primary_color'] = normalize_hex(brief['primary_color'], DEFAULT_BRIEF['primary_color'])
    brief['accent_color']  = normalize_hex(brief['accent_color'],  DEFAULT_BRIEF['accent_color'])
    brief['key_ui_patterns'] = Array(brief['key_ui_patterns']).map(&:to_s).reject(&:blank?).first(5)
    brief
  rescue JSON::ParserError => e
    Rails.logger.warn("MockupGenerationService: design research returned invalid JSON (#{e.message}), using defaults")
    DEFAULT_BRIEF.dup
  end

  def research_prompt
    similar = @cost_estimate.similar_apps_data.map { |a| a['name'] }.compact.first(5)

    <<~PROMPT
      You are a senior UI/UX designer preparing the visual direction for a new product.

      Product: "#{app_name}"
      Description: #{@cost_estimate.description.to_s.truncate(400)}
      Platforms: #{@cost_estimate.platforms.join(', ').presence || 'mobile'}
      Key features: #{top_features.first(6).join(', ')}
      Comparable products: #{similar.join(', ').presence || 'none identified'}

      Research the domain and define a distinctive, appropriate design direction:
      - Choose the right design system foundation: "Material Design 3" for Android/cross-platform,
        "iOS Human Interface Guidelines" for iOS-first, or a modern web design system for web apps.
      - Pick a CUSTOM primary brand color suited to this domain's psychology and audience
        (do NOT default to generic blue; do NOT use red #ED1A3B), plus one complementary accent color.
      - Describe background/surface treatment, typography direction, and overall mood.
      - List 3-5 domain-specific UI patterns this product's screens should feature
        (e.g. for fitness: activity rings, streak counters; for booking: calendar bottom sheets).

      Respond with ONLY a JSON object, no markdown:
      {
        "design_system": "...",
        "primary_color": "#RRGGBB",
        "accent_color": "#RRGGBB",
        "background": "one-line surface/background treatment",
        "typography": "one-line typography direction",
        "mood": "3-5 adjectives",
        "key_ui_patterns": ["...", "..."]
      }
    PROMPT
  end

  def normalize_hex(value, fallback)
    hex = value.to_s.strip
    hex = "##{hex}" unless hex.start_with?('#')
    hex.match?(/\A#\h{6}\z/) ? hex.upcase : fallback
  end

  def screen_specs(brief)
    features = top_features
    summary = @cost_estimate.description.to_s.truncate(220)

    surface = mobile? ? 'mobile app' : 'desktop web application'
    patterns = brief['key_ui_patterns'].any? ? "If one fits naturally, feature ONE domain pattern such as: #{brief['key_ui_patterns'].first(3).join(', ')}." : ''
    style = <<~STYLE.squish
      This is a presentation-grade UI/UX concept mockup — the kind a design studio
      shows in a client pitch deck or a top Dribbble shot. It must look designed by
      a senior product designer, not busy or auto-generated.
      Composition rules (strict): generous white space on an 8pt spacing grid;
      one clear focal point; strong visual hierarchy with one large friendly
      headline; at most 4 UI components on the whole screen; soft rounded cards
      with gentle shadows; short labels of one to three words.
      Absolutely NO dense data tables, NO long lists (3 items maximum), NO tiny
      paragraph text, NO more than one simple chart, NO crowding — when in doubt,
      leave the space empty.
      Design direction (from UI/UX research): follow #{brief['design_system']}
      components and layout conventions. Primary brand color #{brief['primary_color']}
      for key actions and highlights, accent color #{brief['accent_color']} used
      sparingly. Background: #{brief['background']}. Typography: #{brief['typography']}.
      Mood: #{brief['mood']}. #{patterns}
      Pixel-perfect flat UI filling the entire frame — no device frame, no browser
      chrome, no hands, no background scenery, no watermarks.
    STYLE

    [
      {
        slug: 'home-screen',
        prompt: <<~PROMPT.squish
          UI design of a single #{surface} screen for "#{app_name}" — #{summary}
          Screen: the home screen a signed-in user sees. Exactly this content and
          nothing more: a short greeting, ONE hero card for the primary action
          (#{features.first.presence || 'the main feature'}), one or two small
          supporting cards, and simple navigation. A calm, breathable daily view —
          not a dashboard of every feature.
          #{style}
        PROMPT
      },
      {
        slug: key_feature.parameterize.presence || 'key-feature',
        prompt: <<~PROMPT.squish
          UI design of a single #{surface} screen for "#{app_name}" — #{summary}
          Screen: the "#{key_feature}" screen, showing just that single flow in a
          spacious, focused layout with a small amount of believable example data.
          #{style}
        PROMPT
      }
    ]
  end

  # Text request (design research) — forces a JSON response.
  def request_text(model, prompt)
    uri = URI.parse(format(ENDPOINT, model))
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 15
    http.read_timeout = 60

    request = Net::HTTP::Post.new(uri.path, {
      'Content-Type' => 'application/json',
      'x-goog-api-key' => @api_key
    })
    request.body = {
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: {
        responseMimeType: 'application/json',
        temperature: 0.8
      }
    }.to_json

    response = http.request(request)
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.warn("MockupGenerationService: #{model} research returned #{response.code}: #{response.body.to_s.truncate(300)}")
      return nil
    end

    JSON.parse(response.body).dig('candidates', 0, 'content', 'parts', 0, 'text')
  rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
    Rails.logger.warn("MockupGenerationService: #{model} research request failed: #{e.class} #{e.message}")
    nil
  end

  def generate_image(prompt, reference: nil)
    [PRIMARY_MODEL, FALLBACK_MODEL].each do |model|
      png = request_image(model, prompt, reference: reference)
      return png if png.present?
    end
    nil
  end

  def request_image(model, prompt, reference: nil)
    uri = URI.parse(format(ENDPOINT, model))
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = 15
    http.read_timeout = 180

    request = Net::HTTP::Post.new(uri.path, {
      'Content-Type' => 'application/json',
      'x-goog-api-key' => @api_key
    })

    parts = []
    if reference.present?
      parts << { inlineData: { mimeType: 'image/png', data: Base64.strict_encode64(reference) } }
      prompt = <<~REF.squish
        The attached image is another screen of this exact app. Match its visual
        style precisely — identical color palette, typography, corner radii,
        component styling, spacing and iconography — as if both screens came
        from the same design file. #{prompt}
      REF
    end
    parts << { text: prompt }

    request.body = {
      contents: [{ parts: parts }],
      generationConfig: {
        responseModalities: ['IMAGE'],
        imageConfig: { aspectRatio: mobile? ? '9:16' : '16:9' }
      }
    }.to_json

    response = http.request(request)
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.warn("MockupGenerationService: #{model} returned #{response.code}: #{response.body.to_s.truncate(300)}")
      return nil
    end

    payload = JSON.parse(response.body)
    part = payload.dig('candidates', 0, 'content', 'parts')&.find { |p| p['inlineData'] }
    return nil unless part

    Base64.decode64(part['inlineData']['data'])
  rescue JSON::ParserError, Net::OpenTimeout, Net::ReadTimeout, SocketError => e
    Rails.logger.warn("MockupGenerationService: #{model} request failed: #{e.class} #{e.message}")
    nil
  end
end
