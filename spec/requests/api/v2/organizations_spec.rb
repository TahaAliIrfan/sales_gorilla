require "rails_helper"

RSpec.describe "API V2 Organizations", type: :request do
  let(:user)   { create(:user) }
  let!(:org_a) { create(:organization, subdomain: "alpha", name: "Alpha") }
  let!(:org_b) { create(:organization, subdomain: "bravo", name: "Bravo") }
  before { create(:membership, :owner, user: user, organization: org_a) }

  let(:plain_token)  { JsonWebToken.encode(user_id: user.id) }
  let(:scoped_token) { JsonWebToken.encode(user_id: user.id, organization_id: org_a.id) }

  def auth(headers, token)
    headers.merge("Authorization" => "Bearer #{token}")
  end

  describe "GET /api/v2/organizations" do
    it "returns the orgs the user belongs to" do
      get "/api/v2/organizations", headers: auth({}, plain_token)
      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload["data"].pluck("subdomain")).to eq([ "alpha" ])
    end

    it "rejects an unknown JWT user with 401" do
      bad = JsonWebToken.encode(user_id: 999_999)
      get "/api/v2/organizations", headers: auth({}, bad)
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v2/organizations/switch" do
    it "returns a new token carrying the chosen org_id" do
      post "/api/v2/organizations/switch",
           params: { subdomain: "alpha" }.to_json,
           headers: auth({ "Content-Type" => "application/json" }, plain_token)
      expect(response).to have_http_status(:ok)
      new_token = JSON.parse(response.body).dig("data", "token")
      decoded = JsonWebToken.decode(new_token)
      expect(decoded[:user_id]).to eq(user.id)
      expect(decoded[:organization_id]).to eq(org_a.id)
    end

    it "refuses to switch into an org the user doesn't belong to" do
      post "/api/v2/organizations/switch",
           params: { subdomain: "bravo" }.to_json,
           headers: auth({ "Content-Type" => "application/json" }, plain_token)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "tenant resolution priority" do
    it "rejects a token whose organization_id references a missing org" do
      bad_scoped = JsonWebToken.encode(user_id: user.id, organization_id: 999_999)
      get "/api/v2/organizations/current", headers: auth({}, bad_scoped)
      expect(response).to have_http_status(:forbidden)
    end

    it "rejects an X-Organization-Subdomain header pointing at an unknown org" do
      get "/api/v2/organizations/current",
          headers: auth({ "X-Organization-Subdomain" => "nope" }, plain_token)
      expect(response).to have_http_status(:forbidden)
    end

    it "uses the user's first membership when no JWT or header org is set" do
      get "/api/v2/organizations/current", headers: auth({}, plain_token)
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).dig("data", "subdomain")).to eq("alpha")
    end
  end
end
