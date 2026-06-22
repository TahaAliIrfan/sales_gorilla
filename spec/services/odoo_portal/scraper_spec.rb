require "rails_helper"

RSpec.describe OdooPortal::Scraper do
  let(:conn) { build(:odoo_portal_connection) }
  let(:runner) { instance_double(OdooPortal::BrowserRunner) }
  subject(:scraper) { described_class.new(conn, runner: runner) }

  before do
    allow(runner).to receive(:run).with("validate_session").and_return("logged_in" => true)
    allow(runner).to receive(:run).with("list_leads").and_return([
      { "portal_lead_id" => "L1", "title" => "A", "url" => "u1" },
      { "portal_lead_id" => "L2", "title" => "B", "url" => "u2" }
    ])
    allow(runner).to receive(:run).with("show_lead", { "url" => "u2" }).and_return("html" => "<main>B detail</main>")
  end

  it "returns only unknown leads, enriched with detail html" do
    result = scraper.fetch_new(known_ids: ["L1"])
    expect(result.map { |h| h["portal_lead_id"] }).to eq(["L2"])
    expect(result.first["html"]).to include("B detail")
  end
end
