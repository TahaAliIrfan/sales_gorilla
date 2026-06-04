# frozen_string_literal: true

# Controls who can administer the organization itself: its profile, branding,
# and (later) members and billing. Owners and admins of the org, plus global
# Tecaudex admins.
class OrganizationPolicy < ApplicationPolicy
  def show? = user&.membership.present? || user&.user&.admin?

  def edit_branding?   = user&.can_administer?
  def update_branding? = user&.can_administer?

  def update? = user&.can_administer?
  def edit?   = update?

  # Destroying an organization is reserved for the owner (or a global admin).
  def destroy? = user&.org_owner? || user&.user&.admin?
end
