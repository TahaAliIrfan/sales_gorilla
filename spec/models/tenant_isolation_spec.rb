require "rails_helper"

# Whole-class isolation test. The point of acts_as_tenant is that a query
# without a tenant set leaks across orgs, but a query within ActsAsTenant.with_tenant
# only sees that org's rows. This is the regression net for accidental
# acts_as_tenant removals on a tenant model.
RSpec.describe "Tenant isolation" do
  let!(:org_a)      { create(:organization, subdomain: "alpha") }
  let!(:org_b)      { create(:organization, subdomain: "bravo") }
  let!(:customer_a) { ActsAsTenant.with_tenant(org_a) { create(:customer, name: "A's customer") } }
  let!(:customer_b) { ActsAsTenant.with_tenant(org_b) { create(:customer, name: "B's customer") } }

  it "scopes Customer queries to the current tenant" do
    ActsAsTenant.with_tenant(org_a) do
      expect(Customer.pluck(:id)).to eq([ customer_a.id ])
    end

    ActsAsTenant.with_tenant(org_b) do
      expect(Customer.pluck(:id)).to eq([ customer_b.id ])
    end
  end

  it "returns every row when no tenant is set (admin context)" do
    expect(Customer.pluck(:id)).to match_array([ customer_a.id, customer_b.id ])
  end

  it "stamps new records with the current tenant's organization_id" do
    ActsAsTenant.with_tenant(org_a) do
      c = create(:customer, name: "Fresh")
      expect(c.organization_id).to eq(org_a.id)
    end
  end

  it "prevents finding another tenant's record from inside a tenant scope" do
    ActsAsTenant.with_tenant(org_a) do
      expect(Customer.find_by(id: customer_b.id)).to be_nil
    end
  end
end
