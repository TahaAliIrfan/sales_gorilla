module OdooPortal
  class Writer
    def initialize(connection, runner: BrowserRunner.new(connection))
      @runner = runner
    end

    def perform(url:, action:)
      @runner.run("write_action", "url" => url, "kind" => action[:kind], "note" => action[:note])
    end
  end
end
