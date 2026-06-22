require "rails_helper"

RSpec.describe OdooPortal::BrowserRunner do
  let(:conn) { build(:odoo_portal_connection) }
  subject(:runner) { described_class.new(conn) }

  it "returns the agent data on success" do
    allow(Open3).to receive(:capture3).and_return([{ ok: true, data: [{ "portal_lead_id" => "L1" }] }.to_json, "", instance_double(Process::Status, success?: true)])
    expect(runner.run("list_leads")).to eq([{ "portal_lead_id" => "L1" }])
  end

  it "raises AgentError when the agent reports failure" do
    allow(Open3).to receive(:capture3).and_return([{ ok: false, error: "boom" }.to_json, "", instance_double(Process::Status, success?: true)])
    expect { runner.run("list_leads") }.to raise_error(described_class::AgentError, /boom/)
  end

  it "raises SessionExpired when validate_session reports logged_in false" do
    allow(Open3).to receive(:capture3).and_return([{ ok: true, data: { "logged_in" => false } }.to_json, "", instance_double(Process::Status, success?: true)])
    expect { runner.run("validate_session") }.to raise_error(described_class::SessionExpired)
  end
end
