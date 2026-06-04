require "calling/version"
require "calling/engine"

module Calling
  # Provider registry: maps the string stored in OrganizationFeature#provider
  # to the adapter class. New providers register here.
  def self.providers
    @providers ||= {}
  end

  def self.register_provider(name, klass)
    providers[name.to_s] = klass
  end
end
