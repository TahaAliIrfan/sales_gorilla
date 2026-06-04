require "rails_helper"

RSpec.describe Relay::IconHelper, type: :helper do
  it "renders a vendored lucide icon at the requested size and stroke" do
    html = helper.relay_icon("check", size: 20)
    expect(html).to include('class="ic"')
    expect(html).to include('width="20"')
    expect(html).to include('stroke-width="1.9"')
    expect(html).to include("<svg")
  end

  it "renders the hand-vendored linkedin icon" do
    expect(helper.relay_icon("linkedin")).to include("<svg")
  end

  it "renders a visible placeholder for unknown icons instead of raising" do
    html = helper.relay_icon("no-such-icon")
    expect(html).to include("ic--missing")
  end
end
