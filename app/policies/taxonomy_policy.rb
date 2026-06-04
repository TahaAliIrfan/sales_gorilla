# frozen_string_literal: true

# Only organization admins (or a global Tecaudex admin) can manage the
# lookup lists exposed at Settings > Taxonomies.
class TaxonomyPolicy < ApplicationPolicy
  def index?    = user&.can_administer?
  def show?     = user&.can_administer?
  def create?   = user&.can_administer?
  def update?   = user&.can_administer?
  def destroy?  = user&.can_administer?
  def reorder?  = user&.can_administer?
end
