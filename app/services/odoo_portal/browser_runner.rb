require "open3"

module OdooPortal
  # Thin bridge to the Node/Puppeteer agent. One process per action; JSON in/out.
  class BrowserRunner
    class AgentError < StandardError; end
    class SessionExpired < StandardError; end

    SCRIPT = Rails.root.join("lib/odoo_portal/portal_agent.js").to_s

    # Captured from the live portal in a follow-up (needs real creds). Defaults
    # are sane fallbacks; the node agent also has a fallback selector.
    SELECTORS = {
      "row" => ".o_portal_my_doc_table tbody tr"
    }.freeze

    def initialize(connection)
      @connection = connection
    end

    def run(action, payload = {})
      input = {
        action: action,
        base_url: @connection.base_url,
        cookies: @connection.cookies,
        selectors: SELECTORS,
        payload: payload
      }.to_json

      stdout, stderr, status = Open3.capture3("node", SCRIPT, stdin_data: input)
      raise AgentError, "node exited: #{stderr.presence || 'unknown'}" unless status.success?

      parsed = JSON.parse(stdout.presence || "{}")
      raise AgentError, parsed["error"].to_s unless parsed["ok"]

      data = parsed["data"]
      raise SessionExpired if action == "validate_session" && data.is_a?(Hash) && data["logged_in"] == false

      data
    end
  end
end
