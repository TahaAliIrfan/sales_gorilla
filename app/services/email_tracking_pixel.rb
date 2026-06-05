# Injects a 1×1 transparent tracking pixel into an outbound email's HTML body.
# The pixel URL embeds the email's tracking_token; when the recipient renders
# the message, the GET to /e/o/:token.gif records the open via Email#record_open!.
#
# Caveats (documented honestly because every product hits these):
#   - Gmail proxies images through Google's CDN, so the pixel often fires when
#     Gmail's proxy prefetches it, not when the human opens the email. Treat
#     opens as a "delivered + viewable" signal, not literal eyeballs.
#   - Apple Mail's Mail Privacy Protection prefetches images too.
#   - Plain-text-only clients (or recipients who block images) will never fire.
#
# The pixel is intentionally placed at the END of the body so it's the last
# byte rendered — minimizes the chance of it being clipped by mail-client
# "show trimmed content" thresholds.
class EmailTrackingPixel
  def self.inject(html, tracking_token:, base_url:)
    new(html, tracking_token: tracking_token, base_url: base_url).inject
  end

  def initialize(html, tracking_token:, base_url:)
    @html = html.to_s
    @tracking_token = tracking_token
    @base_url = base_url.to_s.chomp("/")
  end

  def inject
    return @html if @tracking_token.blank?
    return @html if @html.include?(pixel_marker) # idempotent — never double-inject

    pixel = pixel_html
    if @html =~ %r{</body>}i
      @html.sub(%r{</body>}i, "#{pixel}</body>")
    else
      @html + pixel
    end
  end

  private

  def pixel_url
    "#{@base_url}/e/o/#{@tracking_token}.gif"
  end

  # The marker is the wrapper class — kept on the <img> so a future re-send of
  # the same email doesn't double-inject.
  def pixel_marker
    'class="tecaudex-open-pixel"'
  end

  def pixel_html
    <<~HTML.squish
      <img src="#{pixel_url}" width="1" height="1"
           alt="" border="0"
           style="display:block;width:1px;height:1px;border:0;opacity:0;pointer-events:none"
           #{pixel_marker} />
    HTML
  end
end
