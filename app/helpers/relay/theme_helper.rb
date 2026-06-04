#
# White-label brand engine — Ruby port of docs/design/relay-ds/project/ds.js
# (applyBrand). A tenant supplies one color (Organization#primary_color);
# we derive the 11-stop --brand-* oklch ramp the entire DS repaints from.
module Relay
  module ThemeHelper
    # Shared lightness curve + per-stop chroma multipliers (from ds.js).
    BRAND_L     = [0.984, 0.954, 0.910, 0.846, 0.762, 0.682, 0.586, 0.498, 0.420, 0.350, 0.272].freeze
    BRAND_CMUL  = [0.16, 0.34, 0.56, 0.78, 0.93, 1.0, 0.90, 0.76, 0.62, 0.48, 0.37].freeze
    BRAND_STEPS = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900, 950].freeze

    DEFAULT_BRAND_HEX = "#0F766E" # Relay demo teal
    CHROMA_RANGE = (0.03..0.22)   # keep near-grays visible, loud colors calm

    def relay_brand_style_tag(organization)
      hex = organization&.primary_color.presence || DEFAULT_BRAND_HEX
      _l, c, h = relay_hex_to_oklch(hex)
      c = c.clamp(CHROMA_RANGE.min, CHROMA_RANGE.max)
      props = BRAND_STEPS.each_with_index.map do |step, i|
        "--brand-#{step}:oklch(#{BRAND_L[i]} #{(c * BRAND_CMUL[i]).round(3)} #{h.round(1)})"
      end
      tag.style(":root{#{props.join(';')}}".html_safe)
    end

    # sRGB hex -> OKLCh [lightness, chroma, hue-degrees] (Björn Ottosson's OKLab).
    def relay_hex_to_oklch(hex)
      hex = hex.to_s.delete("#")
      hex = hex.chars.map { |ch| ch * 2 }.join if hex.length == 3
      r, g, b = [hex[0, 2], hex[2, 2], hex[4, 2]].map { |p| srgb_channel_to_linear(p.to_i(16) / 255.0) }

      l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
      m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
      s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
      l_, m_, s_ = [l, m, s].map { |v| Math.cbrt(v) }

      lab_l = 0.2104542553 * l_ + 0.7936177850 * m_ - 0.0040720468 * s_
      lab_a = 1.9779984951 * l_ - 2.4285922050 * m_ + 0.4505937099 * s_
      lab_b = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.8086757660 * s_

      chroma = Math.sqrt(lab_a**2 + lab_b**2)
      hue = Math.atan2(lab_b, lab_a) * 180.0 / Math::PI
      hue += 360 if hue.negative?
      [lab_l, chroma, hue]
    end

    private

    def srgb_channel_to_linear(c)
      c <= 0.04045 ? c / 12.92 : ((c + 0.055) / 1.055)**2.4
    end
  end
end
