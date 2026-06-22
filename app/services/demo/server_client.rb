require "httparty"

module Demo
  # Talks to the demo-builder endpoint on the demo server (demo.tecaudex.pk),
  # which spins up a fresh branded Odoo demo DB and returns its coordinates.
  # Per-org configurable (server_url + api_key) via the `demo_engine` feature.
  class ServerClient
    class BuildError < StandardError; end

    DEFAULT_URL = "https://demo.tecaudex.pk".freeze

    attr_reader :server_url, :api_key

    def self.for_organization(org)
      feature = org&.feature("demo_engine")
      url = feature&.settings_for("server_url").presence || ENV["DEMO_SERVER_URL"].presence || DEFAULT_URL
      key = feature&.settings_for("api_key").presence || ENV["DEMO_SERVER_KEY"]
      new(server_url: url, api_key: key)
    end

    def initialize(server_url:, api_key: nil)
      @server_url = server_url.to_s.chomp("/")
      @api_key = api_key
    end

    def build(company:, industry:, brand: nil, ref: nil)
      resp = HTTParty.post("#{@server_url}/build",
        headers: { "content-type" => "application/json", "authorization" => "Bearer #{@api_key}" },
        body: { company: company, industry: industry, brand: brand, ref: ref }.to_json,
        timeout: 180)
      raise BuildError, "demo server #{resp.code}: #{resp.body.to_s[0, 200]}" unless resp.code == 200
      resp.parsed_response
    end
  end
end
