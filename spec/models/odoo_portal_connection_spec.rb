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
end
