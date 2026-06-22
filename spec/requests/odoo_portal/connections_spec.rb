require "rails_helper"

RSpec.describe "Odoo portal connection settings", type: :request do
  let(:org)  { create(:organization, subdomain: "odoo-conn-test") }
  let(:host) { "#{org.subdomain}.example.com" }
  let(:admin) { create(:user, confirmed_at: Time.current) }

  before do
    host! host
    ActsAsTenant.with_tenant(org) do
      create(:membership, :admin, user: admin, organization: org)
    end
    allow_any_instance_of(ApplicationController).to receive(:current_user).and_return(admin)
  end

  it "saves a connection and marks it active" do
    cookies_json = [{ "name" => "session_id", "value" => "z" }].to_json
    post settings_odoo_portal_connection_path, params: {
      odoo_portal_connection: { base_url: "https://www.odoo.com", watch_from: "odoo.com", watch_subject: "Lead", session_cookies: cookies_json }
    }
    conn = ActsAsTenant.with_tenant(org) { OdooPortalConnection.for_organization(org) }
    expect(conn).to be_present
    expect(conn.status).to eq("active")
    expect(conn.cookies.first["value"]).to eq("z")
  end

  it "logs in with email + password and stores the captured session" do
    runner = instance_double(OdooPortal::BrowserRunner)
    allow(OdooPortal::BrowserRunner).to receive(:new).and_return(runner)
    allow(runner).to receive(:login).and_return([{ "name" => "session_id", "value" => "z" }])

    post settings_odoo_portal_connection_path, params: {
      odoo_portal_connection: { base_url: "https://www.odoo.com", login_email: "a@b.com", login_password: "secret" }
    }
    conn = ActsAsTenant.with_tenant(org) { OdooPortalConnection.for_organization(org) }
    expect(conn.status).to eq("active")
    expect(conn.cookies.first["value"]).to eq("z")
    expect(conn.login_email).to eq("a@b.com")
  end

  it "seeds the lead-source taxonomy entry for 'Odoo Partner Portal' on connect" do
    cookies_json = [{ "name" => "session_id", "value" => "z" }].to_json
    post settings_odoo_portal_connection_path, params: {
      odoo_portal_connection: { base_url: "https://www.odoo.com", watch_from: "odoo.com", watch_subject: "Lead", session_cookies: cookies_json }
    }
    expect(org.taxonomies.where(kind: "lead_source", name: "Odoo Partner Portal")).to exist
  end
end
