#
# Inline-SVG Lucide icons (vendored under app/assets/images/lucide via
# bin/relay_icons). Mirrors the prototype's Icon component: span.ic wrapper,
# default 18px, 1.9 stroke. Icons inherit currentColor.
module Relay
  module IconHelper
    LUCIDE_DIR = Rails.root.join("app/assets/images/lucide")

    def relay_icon(name, size: 18, stroke: 1.9, css: nil)
      raw = relay_icon_source(name.to_s)
      style = "display:inline-flex;width:#{size.to_i}px;height:#{size.to_i}px;flex:none"
      unless raw
        Rails.logger.warn("relay_icon: missing icon #{name} — run bin/relay_icons") if Rails.env.development?
        return tag.span(class: "ic ic--missing", style: style, title: "missing icon: #{name}")
      end
      svg = raw.sub("<svg", %(<svg width="#{size.to_i}" height="#{size.to_i}" stroke-width="#{stroke}"))
      tag.span(svg.html_safe, class: ["ic", css].compact.join(" "), style: style)
    end

    private

    # Strip the source width/height/stroke-width so per-call values apply.
    # Cached per-process in production; re-read each call in development.
    def relay_icon_source(name)
      return read_icon(name) if Rails.env.development?
      (@@relay_icon_cache ||= {})[name] ||= read_icon(name)
    end

    def read_icon(name)
      path = LUCIDE_DIR.join("#{name}.svg")
      return nil unless name.match?(/\A[a-z0-9-]+\z/) && path.exist?
      path.read.gsub(/\s(width|height|stroke-width)="[^"]*"/, "")
    end
  end
end
