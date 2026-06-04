require_relative "lib/calling/version"

Gem::Specification.new do |spec|
  spec.name        = "calling"
  spec.version     = Calling::VERSION
  spec.authors     = [ "Tecaudex" ]
  spec.summary     = "Calling module for the Tecaudex ERP platform."
  spec.description = "Provides browser-based calling, recordings, and transcription via swappable provider adapters (Twilio, …)."
  spec.license     = "Proprietary"

  spec.files = Dir["{app,config,lib}/**/*", "README.md"]

  spec.add_dependency "rails", ">= 7.1"
  spec.add_dependency "twilio-ruby", "~> 7.8"
end
