require "rails_helper"

RSpec.describe Organization do
  describe "validations" do
    it "is valid with a name, subdomain, and default colors" do
      expect(build(:organization)).to be_valid
    end

    it "requires a name" do
      org = build(:organization, name: nil)
      expect(org).not_to be_valid
      expect(org.errors[:name]).to include("can't be blank")
    end

    it "rejects reserved subdomains" do
      %w[www admin api].each do |sub|
        org = build(:organization, subdomain: sub)
        expect(org).not_to be_valid
        expect(org.errors[:subdomain]).to include("is reserved")
      end
    end

    it "rejects subdomains with invalid characters" do
      org = build(:organization, subdomain: "Hello World")
      expect(org).not_to be_valid
      expect(org.errors[:subdomain]).to be_present
    end

    it "rejects malformed hex colors" do
      org = build(:organization, primary_color: "not-a-color")
      expect(org).not_to be_valid
      expect(org.errors[:primary_color]).to be_present
    end

    it "enforces subdomain uniqueness case-insensitively" do
      create(:organization, subdomain: "acme")
      dup = build(:organization, subdomain: "ACME")
      expect(dup).not_to be_valid
    end
  end

  describe "#initial" do
    it "returns the uppercase first letter of the name" do
      expect(build(:organization, name: "tecaudex").initial).to eq("T")
    end

    it "returns '?' when name is blank" do
      expect(Organization.new.initial).to eq("?")
    end
  end

  describe "normalizations" do
    it "downcases and strips subdomain before validation" do
      org = build(:organization, subdomain: "  ACME  ")
      org.valid?
      expect(org.subdomain).to eq("acme")
    end
  end
end
