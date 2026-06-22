require "rails_helper"

RSpec.describe Customer do
  it "persists demo fields and encrypts the password" do
    org = create(:organization)
    c = ActsAsTenant.with_tenant(org) do
      create(:customer, organization: org, demo_url: "https://demo.tecaudex.pk", demo_db: "lead42",
             demo_login: "admin", demo_password: "secret", demo_status: "ready", demo_built_at: Time.current)
    end
    expect(c.reload).to have_attributes(demo_url: "https://demo.tecaudex.pk", demo_db: "lead42", demo_status: "ready")
    expect(c.demo_password).to eq("secret")
    # encrypted at rest: the raw column value should not be the plaintext
    raw = Customer.connection.select_value("select demo_password from customers where id = #{c.id}")
    expect(raw).not_to eq("secret")
  end

  it "supports a demo_guide attachment" do
    org = create(:organization)
    c = ActsAsTenant.with_tenant(org) { create(:customer, organization: org) }
    expect(c).to respond_to(:demo_guide)
  end
end
