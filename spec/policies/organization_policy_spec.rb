require "rails_helper"

RSpec.describe OrganizationPolicy do
  let(:org)  { create(:organization) }
  let(:user) { create(:user) }

  def context_for(role)
    membership = role && create(:membership, user: user, organization: org, role: role)
    UserContext.new(user: user, organization: org, membership: membership)
  end

  describe "#edit_branding?" do
    it "permits owners"  do expect(described_class.new(context_for("owner"),  org).edit_branding?).to be true  end
    it "permits admins"  do expect(described_class.new(context_for("admin"),  org).edit_branding?).to be true  end
    it "rejects members" do expect(described_class.new(context_for("member"), org).edit_branding?).to be false end
    it "rejects viewers" do expect(described_class.new(context_for("viewer"), org).edit_branding?).to be false end
    it "rejects non-members" do
      expect(described_class.new(context_for(nil), org).edit_branding?).to be false
    end
  end

  describe "#destroy?" do
    it "permits owners" do
      expect(described_class.new(context_for("owner"), org).destroy?).to be true
    end

    it "rejects admins" do
      expect(described_class.new(context_for("admin"), org).destroy?).to be false
    end
  end
end
