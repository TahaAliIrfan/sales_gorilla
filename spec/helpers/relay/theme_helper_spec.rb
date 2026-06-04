require "rails_helper"

RSpec.describe Relay::ThemeHelper, type: :helper do
  describe "#relay_hex_to_oklch" do
    it "converts pure red to the known oklch value" do
      l, c, h = helper.relay_hex_to_oklch("#ff0000")
      expect(l).to be_within(0.005).of(0.628)
      expect(c).to be_within(0.005).of(0.258)
      expect(h).to be_within(0.5).of(29.23)
    end

    it "handles 3-digit hex and near-gray without NaN" do
      l, c, h = helper.relay_hex_to_oklch("#888")
      expect(l).to be_between(0.5, 0.7)
      expect(c).to be < 0.01
      expect(h).to be_a(Float)
    end
  end

  describe "#relay_brand_style_tag" do
    let(:org) { build(:organization, primary_color: "#0F766E") }

    it "renders a style tag with all 11 brand stops sharing the seed hue" do
      html = helper.relay_brand_style_tag(org)
      expect(html).to start_with("<style>")
      stops = html.scan(/--brand-(\d+):oklch\(([\d.]+) ([\d.]+) ([\d.]+)\)/)
      expect(stops.map(&:first)).to eq(%w[50 100 200 300 400 500 600 700 800 900 950])
      hues = stops.map { |s| s[3].to_f }.uniq
      expect(hues.size).to eq(1)
      lightnesses = stops.map { |s| s[1].to_f }
      expect(lightnesses).to eq(lightnesses.sort.reverse) # 50 lightest → 950 darkest
    end

    it "falls back to the Relay teal when organization is nil" do
      expect(helper.relay_brand_style_tag(nil)).to include("--brand-500:oklch(")
    end

    it "clamps chroma so near-gray brands stay visible" do
      gray = build(:organization, primary_color: "#808080")
      html = helper.relay_brand_style_tag(gray)
      c500 = html[/--brand-500:oklch\([\d.]+ ([\d.]+)/, 1].to_f
      expect(c500).to be >= 0.03
    end
  end
end
