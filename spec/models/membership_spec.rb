require "rails_helper"

RSpec.describe Membership do
  describe "validations" do
    it "is valid with user, organization, and role" do
      expect(build(:membership)).to be_valid
    end

    it "requires a role in the allowed list" do
      m = build(:membership, role: "wizard")
      expect(m).not_to be_valid
      expect(m.errors[:role]).to be_present
    end

    it "prevents duplicate membership in the same organization" do
      user = create(:user)
      org  = create(:organization)
      create(:membership, user: user, organization: org)
      dup  = build(:membership, user: user, organization: org)
      expect(dup).not_to be_valid
    end

    it "allows the same user to belong to different organizations" do
      user = create(:user)
      create(:membership, user: user, organization: create(:organization))
      second = build(:membership, user: user, organization: create(:organization))
      expect(second).to be_valid
    end
  end

  describe "role predicates" do
    Membership::ROLES.each do |role|
      it "exposes #{role}? as true only for that role" do
        m = build(:membership, role: role)
        expect(m.public_send("#{role}?")).to be true
        (Membership::ROLES - [ role ]).each do |other|
          expect(m.public_send("#{other}?")).to be false
        end
      end
    end
  end
end
