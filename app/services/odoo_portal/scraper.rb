module OdooPortal
  # Diffs the portal leads list against already-known ids and pulls detail HTML
  # for the new ones only. Validates the session up front so an expired session
  # surfaces as SessionExpired before we do any work.
  class Scraper
    def initialize(connection, runner: BrowserRunner.new(connection))
      @runner = runner
    end

    def fetch_new(known_ids:)
      @runner.run("validate_session")
      list = Array(@runner.run("list_leads"))
      list.reject { |row| known_ids.include?(row["portal_lead_id"]) }.map do |row|
        detail = @runner.run("show_lead", "url" => row["url"])
        row.merge("html" => detail["html"])
      end
    end
  end
end
