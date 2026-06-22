require "rails_helper"

RSpec.describe OdooPortalConnection do
  it "is active when status is active" do
    expect(build(:odoo_portal_connection, status: "active")).to be_active
  end

  it "mark_needs_reauth! flips status and clears cookies" do
    conn = create(:odoo_portal_connection, status: "active")
    conn.mark_needs_reauth!
    expect(conn.reload.status).to eq("needs_reauth")
  end

  it "for_organization finds the row ignoring tenant scope" do
    org = create(:organization)
    conn = ActsAsTenant.with_tenant(org) { create(:odoo_portal_connection, organization: org) }
    found = ActsAsTenant.without_tenant { OdooPortalConnection.for_organization(org) }
    expect(found).to eq(conn)
  end

  it "credentials? reflects whether email + password are present" do
    expect(build(:odoo_portal_connection, login_email: "a@b.com", login_password: "x")).to be_credentials
    expect(build(:odoo_portal_connection, login_email: nil, login_password: nil)).not_to be_credentials
  end

  it "refresh_session! re-logs in and stores fresh cookies" do
    conn = create(:odoo_portal_connection, login_email: "a@b.com", login_password: "x", status: "needs_reauth", session_cookies: nil)
    runner = instance_double(OdooPortal::BrowserRunner)
    allow(OdooPortal::BrowserRunner).to receive(:new).and_return(runner)
    allow(runner).to receive(:login).and_return([{ "name" => "session_id", "value" => "new" }])

    expect(conn.refresh_session!).to be(true)
    expect(conn.reload.status).to eq("active")
    expect(conn.cookies.first["value"]).to eq("new")
  end

  it "refresh_session! returns false without credentials" do
    conn = create(:odoo_portal_connection, login_email: nil, login_password: nil)
    expect(conn.refresh_session!).to be(false)
  end
end
