require "rails_helper"

RSpec.describe Demo::ServerClient do
  def ok(body)
    instance_double(HTTParty::Response, code: 200, parsed_response: body)
  end

  describe ".for_organization" do
    it "uses the org's demo_engine settings when present" do
      org = create(:organization)
      ActsAsTenant.with_tenant(org) do
        org.features.create!(key: "demo_engine", provider: "odoo", enabled: true,
                             settings: { "server_url" => "https://demo.example.com", "api_key" => "k1" })
      end
      client = described_class.for_organization(org)
      expect(client.server_url).to eq("https://demo.example.com")
      expect(client.api_key).to eq("k1")
    end

    it "defaults to demo.tecaudex.pk" do
      org = create(:organization)
      expect(described_class.for_organization(org).server_url).to eq("https://demo.tecaudex.pk")
    end
  end

  describe "#build" do
    subject(:client) { described_class.new(server_url: "https://demo.tecaudex.pk", api_key: "k") }

    it "posts the build request and returns the demo coordinates" do
      expect(HTTParty).to receive(:post) do |url, opts|
        expect(url).to eq("https://demo.tecaudex.pk/build")
        body = JSON.parse(opts[:body])
        expect(body).to include("company" => "Nurikon", "industry" => "manufacturing")
        expect(opts[:headers]["authorization"]).to eq("Bearer k")
        ok("url" => "https://demo.tecaudex.pk/web?db=lead42", "db" => "lead42", "login" => "admin", "password" => "p")
      end
      result = client.build(company: "Nurikon", industry: "manufacturing", brand: "#1E3A8A", ref: 42)
      expect(result).to include("db" => "lead42", "login" => "admin")
    end

    it "raises BuildError on a non-200" do
      allow(HTTParty).to receive(:post).and_return(instance_double(HTTParty::Response, code: 500, body: "boom"))
      expect { client.build(company: "X", industry: "services") }.to raise_error(described_class::BuildError)
    end
  end
end
