require "rails_helper"

RSpec.describe UserContext do
  let(:user) { create(:user) }
  let(:org)  { create(:organization) }

  describe "org-role predicates" do
    it "is org_owner? for an owner membership" do
      m = create(:membership, :owner, user: user, organization: org)
      ctx = described_class.new(user: user, organization: org, membership: m)
      expect(ctx.org_owner?).to be true
      expect(ctx.org_admin?).to be false
    end

    it "is org_admin? for an admin membership" do
      m = create(:membership, :admin, user: user, organization: org)
      ctx = described_class.new(user: user, organization: org, membership: m)
      expect(ctx.org_admin?).to be true
      expect(ctx.org_owner?).to be false
    end
  end

  describe "#can_administer?" do
    it "is true for org owners" do
      m = create(:membership, :owner, user: user, organization: org)
      expect(described_class.new(user: user, organization: org, membership: m).can_administer?).to be true
    end

    it "is true for org admins" do
      m = create(:membership, :admin, user: user, organization: org)
      expect(described_class.new(user: user, organization: org, membership: m).can_administer?).to be true
    end

    it "is false for plain members" do
      m = create(:membership, :member, user: user, organization: org)
      expect(described_class.new(user: user, organization: org, membership: m).can_administer?).to be false
    end

    it "is false for viewers" do
      m = create(:membership, :viewer, user: user, organization: org)
      expect(described_class.new(user: user, organization: org, membership: m).can_administer?).to be false
    end
  end

  describe "#can_write?" do
    it "is false for viewers" do
      m = create(:membership, :viewer, user: user, organization: org)
      expect(described_class.new(user: user, organization: org, membership: m).can_write?).to be false
    end

    it "is true for members" do
      m = create(:membership, :member, user: user, organization: org)
      expect(described_class.new(user: user, organization: org, membership: m).can_write?).to be true
    end

    it "is false without a membership" do
      expect(described_class.new(user: user, organization: org, membership: nil).can_write?).to be false
    end
  end

  describe "method delegation" do
    it "delegates unknown methods to the wrapped user" do
      ctx = described_class.new(user: user, organization: org, membership: nil)
      expect(ctx.email).to eq(user.email)
    end
  end
end
