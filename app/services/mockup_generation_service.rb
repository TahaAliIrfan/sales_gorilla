require 'net/http'
require 'json'
require 'base64'
require 'grover'
require 'openai'

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
  OPENAI_MODEL   = 'gpt-5.5'.freeze
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
    @openai_key    = ENV['OPENAI_API_KEY'].presence || Rails.application.credentials.OPENAI_API_KEY
    @anthropic_key = Rails.application.credentials.dig(:ANTHROPIC_API_KEY) || ENV['ANTHROPIC_API_KEY']
    @api_key = Rails.application.credentials.dig(:GOOGLE_STUDIO_API_KEY) || ENV['GOOGLE_STUDIO_API_KEY']
  end

  # Returns true if at least one mockup ends up attached.
  def generate_and_attach
    return true if @cost_estimate.mockup_images.attached?
    raise 'cost estimate must be persisted to attach mockups' unless @cost_estimate.persisted?

    pngs = generate_pngs
    return false if pngs.blank?
    attach_screens(pngs) { |png| png }.positive?
  end

  # Produce the mockup images WITHOUT touching the DB, so the proposal worker can
  # run this in a thread (no connection checkout) and attach them on the main
  # thread. Returns [[slug, png_bytes], ...] (possibly empty).
  def generate_pngs
    screens = authored_screens
    if screens.present?
      pngs = screens.filter_map do |slug, html|
        png = render_screenshot(html)
        [slug, png] if png.present?
      end
      return pngs if pngs.any?
      Rails.logger.warn('MockupGenerationService: HTML pipeline produced no renderable screens, falling back to image models')
    end
    gemini_pngs
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

  # Back-end / plumbing work that has no meaningful screen to draw — excluded
  # when choosing which feature to mock up so we never render an "API Development"
  # or "Database Setup" screen.
  NON_VISUAL = /\b(api|backend|database|infrastructure|hosting|deployment|devops|
                  server|authentication|auth|security|encryption|integration|
                  testing|\bqa\b|documentation|ci\/cd|migration|architecture|
                  sdk|webhook|scalab|monitoring|logging|caching|
                  responsive|web\ interface|ui\/ux|user\ interface|
                  cross.?platform|native\ app|wireframe|prototype|
                  design|figma|mockup|high.?fidelity|style\ guide|
                  design\ system|branding|ui\ kit)\b/xi

  # Features that map to a real, user-facing screen (best candidates first).
  def user_facing_features
    visual = top_features.reject { |f| f.match?(NON_VISUAL) }
    visual.presence || top_features
  end

  def key_feature
    user_facing_features.first.presence || 'the core feature'
  end

  def mobile?
    @cost_estimate.mobile_app?
  end

  def viewport
    mobile? ? MOBILE_VIEWPORT : WEB_VIEWPORT
  end

  # A clean, universal fallback theme when category research is unavailable.
  UNIVERSAL_THEME = {
    'design_language' => 'Material Design 3',
    'primary'         => '#2563EB',
    'accent'          => '#F59E0B',
    'neutral'         => 'near-black text (#0F172A) on white and soft neutral surfaces',
    'font'            => 'Inter (headings + body) with a clear type scale',
    'mood'            => 'clean, modern, trustworthy',
    'reference_apps'  => []
  }.freeze

  # R&D the visual theme from what real apps in this category actually use, so
  # the mockups feel native to the space. Falls back to a universal Material
  # theme if research is unavailable. Memoised (used once per generation).
  def theme_brief
    return @theme_brief if defined?(@theme_brief)

    raw = request_openai(theme_prompt, max_tokens: 3000) if @openai_key.present?
    parsed = raw.present? ? (JSON.parse(raw[/\{.*\}/m].to_s) rescue {}) : {}
    parsed = {} unless parsed.is_a?(Hash)
    @theme_brief = UNIVERSAL_THEME.merge(parsed.slice(*UNIVERSAL_THEME.keys))
  rescue => e
    Rails.logger.warn("MockupGenerationService: theme research failed (#{e.message}), using universal theme")
    @theme_brief = UNIVERSAL_THEME.dup
  end

  def theme_reference_note
    apps = Array(theme_brief['reference_apps']).reject(&:blank?).first(3)
    apps.any? ? " (like #{apps.join(', ')})" : ""
  end

  def theme_prompt
    <<~PROMPT
      You are a brand and product designer. Decide the visual theme for the app
      below, grounded in what LEADING REAL APPS in this same category actually use
      (their typical colour palettes, typography and overall design language). If
      the category is unclear, use a clean, universal Material Design 3 theme.

      App: "#{app_name}" — #{@cost_estimate.description.to_s.truncate(300)}
      Key features: #{user_facing_features.first(6).join(', ')}

      Return ONLY this JSON, no commentary:
      {
        "design_language": "e.g. Material Design 3 / iOS Human Interface / clean SaaS dashboard",
        "primary": "#RRGGBB",
        "accent": "#RRGGBB",
        "neutral": "short description of text and surface neutrals",
        "font": "a Google Font pairing to use",
        "mood": "3-4 adjectives",
        "reference_apps": ["2-3 real apps in this category whose look informs this theme"]
      }
    PROMPT
  end

  # ── Primary pipeline: an LLM writes the UI, Chrome photographs it ──────
  # GPT (gpt-5.5) authors the screens first; Claude is the fallback author.
  # Real HTML rendered by Chrome = pixel-crisp, Figma-grade screens.

  # Returns [[slug, html], [slug, html]] (home first) or nil on failure.
  def authored_screens
    prompt = screens_prompt
    raw = request_openai(prompt) if @openai_key.present?
    if raw.blank? && @anthropic_key.present?
      Rails.logger.info('MockupGenerationService: OpenAI author unavailable/empty, trying Claude')
      raw = request_claude(prompt)
    end
    return nil if raw.blank?

    docs = raw.split(SCREEN_BREAK).map(&:strip).reject(&:blank?)
    docs = docs.map { |d| d.sub(/\A```html?\s*/i, '').sub(/```\z/, '').strip }
    docs = docs.select { |d| d.match?(/<html/i) && d.match?(/<\/html>/i) }

    unless docs.size == 2
      Rails.logger.warn("MockupGenerationService: expected 2 HTML screens, got #{docs.size}")
      return nil
    end

    [
      ['home-screen', docs[0]],
      [key_feature.parameterize.presence || 'key-feature', docs[1]]
    ]
  end

  def request_openai(prompt, max_tokens: 40_000)
    client = OpenAI::Client.new(access_token: @openai_key, request_timeout: 300)
    # Big budget + low reasoning so gpt-5.5 doesn't burn the whole budget
    # reasoning and return an empty body (two full HTML screens are large).
    response = client.chat(parameters: {
      model: OPENAI_MODEL,
      messages: [{ role: 'user', content: prompt }],
      max_completion_tokens: max_tokens,
      reasoning_effort: 'low'
    })
    response.dig('choices', 0, 'message', 'content')
  rescue => e
    Rails.logger.warn("MockupGenerationService: OpenAI request failed: #{e.class} #{e.message}")
    nil
  end

  def screens_prompt
    features = user_facing_features
    vp       = viewport
    surface  = mobile? ? "mobile app (viewport exactly #{vp[:width]}x#{vp[:height]})" :
                         "desktop web application (viewport exactly #{vp[:width]}x#{vp[:height]})"

    <<~PROMPT
      Create me two #{surface} mockup screens for this app idea:

      "#{app_name}" — #{@cost_estimate.description.to_s.truncate(400)}
      Key features: #{features.first(6).join(', ')}

      Use this visual theme, modelled on leading apps in this category#{theme_reference_note}:
      - Design language: #{theme_brief['design_language']}
      - Primary colour: #{theme_brief['primary']}
      - Accent colour: #{theme_brief['accent']}
      - Neutrals: #{theme_brief['neutral']}
      - Typography: #{theme_brief['font']}
      - Mood: #{theme_brief['mood']}
      Apply this theme identically across both screens.

      These must look like a pixel-perfect, production-grade Figma design an agency
      would hand a client: precise 8pt spacing, a clear type hierarchy, consistent
      corner radii and soft shadows, aligned grids, real iconography, and generous
      but purposeful whitespace. No rough edges, no placeholder-looking blocks.

      Both screens are real user-facing product screens — the kind an end user
      taps through. Screen 1 is the main Home / Dashboard screen. Screen 2 is the
      "#{key_feature}" screen. NEVER draw a technical, developer or architecture
      view (no API design, database schema, code, settings/config dumps or
      admin panels) — only screens a normal user would actually see and use.

      CONSISTENCY IS CRITICAL — the two screens must look like they came from the
      SAME Figma file by the same designer. Before writing, lock ONE design system
      and reuse it identically on both screens: the same colours, the same Google
      Font pairing and type scale, the same corner radius, shadow style, spacing
      rhythm and button style, and the same top bar / navigation and icon style.
      Do not restyle anything between screen 1 and screen 2.

      All visible text must be realistic product content — real labels, names,
      numbers and dates. NEVER show colour codes, hex values, CSS variable names,
      or design-token names as text in the UI. Buttons say things like "Continue"
      or "New Task", not a hex code. Fill the screen comfortably; avoid large
      empty areas at the bottom.

      Technical requirements (so the screens render correctly):
      - Two complete standalone HTML documents, each with everything inline.
        Put the shared design tokens in :root CSS variables and reuse them on both.
      - html,body: margin 0; width #{vp[:width]}px; height #{vp[:height]}px; overflow hidden.
        Everything must fit inside the viewport — no scrolling or clipping, and the
        layout should fill the viewport rather than leaving big empty space.
      - No JavaScript, no external images or CDN libraries. Google Fonts @import is fine.
        Use inline SVG for icons; use initials-in-circles for avatars.

      Output the first HTML document, then a line containing exactly
      #{SCREEN_BREAK}
      then the second HTML document. No markdown fences, no commentary.
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
      max_tokens: 40_000,  # two full standalone HTML screens can be large; avoid truncating screen 2
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

  # Returns [[slug, png], ...] from the Gemini image fallback (no DB writes).
  def gemini_pngs
    if @api_key.blank?
      Rails.logger.warn('MockupGenerationService: GOOGLE_STUDIO_API_KEY not configured, skipping fallback mockups')
      return []
    end

    brief = design_brief
    Rails.logger.info("MockupGenerationService: fallback design brief — #{brief['design_system']}, primary #{brief['primary_color']}")

    home_spec, feature_spec = screen_specs(brief)

    # The single-flow feature screen renders most reliably, so generate it
    # first and feed it back as a style reference for the home screen.
    feature_png = generate_image(feature_spec[:prompt])
    home_png    = generate_image(home_spec[:prompt], reference: feature_png)

    [
      [home_spec[:slug],    home_png],
      [feature_spec[:slug], feature_png]
    ].select { |_slug, png| png.present? }
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
