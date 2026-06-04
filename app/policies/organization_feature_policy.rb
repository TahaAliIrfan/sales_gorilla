# frozen_string_literal: true

# Only organization admins/owners (or a global Tecaudex admin) can toggle
# modules and configure provider credentials.
class OrganizationFeaturePolicy < ApplicationPolicy
  def index?  = user&.can_administer?
  def show?   = user&.can_administer?
  def update? = user&.can_administer?
end
