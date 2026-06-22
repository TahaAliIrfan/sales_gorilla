require "rails_helper"

RSpec.describe Ai::Client do
  def ok_response(text)
    instance_double(HTTParty::Response, code: 200, parsed_response: { "content" => [{ "type" => "text", "text" => text }] })
  end

  describe ".for_organization" do
    it "uses the org's ai-feature api_key + model when present" do
      org = create(:organization)
      ActsAsTenant.with_tenant(org) do
        org.features.create!(key: "ai", provider: "claude", enabled: true, settings: { "api_key" => "sk-org", "model" => "claude-x" })
      end
      client = described_class.for_organization(org)
      expect(client.api_key).to eq("sk-org")
      expect(client.model).to eq("claude-x")
    end

    it "falls back to ENV ANTHROPIC_API_KEY and the default model" do
      org = create(:organization)
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return("sk-env")
      client = described_class.for_organization(org)
      expect(client.api_key).to eq("sk-env")
      expect(client.model).to eq(described_class::DEFAULT_MODEL)
    end
  end

  describe "#complete" do
    subject(:client) { described_class.new(api_key: "sk", model: "m") }

    it "posts to the messages endpoint and returns the text" do
      expect(HTTParty).to receive(:post).with(
        described_class::ENDPOINT, hash_including(headers: hash_including("x-api-key" => "sk"))
      ).and_return(ok_response("hello"))
      expect(client.complete(system: "sys", prompt: "hi")).to eq("hello")
    end

    it "raises MissingKey when no key" do
      expect { described_class.new(api_key: nil).complete(system: "s", prompt: "p") }
        .to raise_error(Ai::Client::MissingKey)
    end

    it "raises ApiError on a non-200" do
      allow(HTTParty).to receive(:post).and_return(instance_double(HTTParty::Response, code: 401, body: "nope"))
      expect { client.complete(system: "s", prompt: "p") }.to raise_error(Ai::Client::ApiError)
    end
  end

  describe "#research" do
    subject(:client) { described_class.new(api_key: "sk") }
    it "includes the web_search tool in the request body" do
      expect(HTTParty).to receive(:post) do |_url, opts|
        body = JSON.parse(opts[:body])
        expect(body["tools"].first["type"]).to match(/web_search/)
        ok_response("researched")
      end
      expect(client.research(prompt: "research X")).to eq("researched")
    end
  end
end
