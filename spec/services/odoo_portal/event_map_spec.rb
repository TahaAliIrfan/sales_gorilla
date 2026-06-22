require "rails_helper"

RSpec.describe OdooPortal::EventMap do
  it "maps a not-interested customer to a portal exception" do
    c = build(:customer, status: "Not Interested")
    expect(described_class.action_for(c)).to include(kind: "exception")
  end

  it "maps contact established to a logged note" do
    c = build(:customer, status: "Contact Established")
    expect(described_class.action_for(c)).to include(kind: "note")
  end

  it "returns nil for unmapped statuses" do
    expect(described_class.action_for(build(:customer, status: "Pending"))).to be_nil
  end
end
