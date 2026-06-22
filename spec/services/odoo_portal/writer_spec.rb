require "rails_helper"

RSpec.describe OdooPortal::Writer do
  let(:conn) { build(:odoo_portal_connection) }
  let(:runner) { instance_double(OdooPortal::BrowserRunner) }

  it "invokes the agent write_action with the lead url + action" do
    expect(runner).to receive(:run).with("write_action", hash_including("kind" => "exception"))
    described_class.new(conn, runner: runner).perform(url: "u1", action: { kind: "exception", note: "x" })
  end
end
