module Admin
  # Base for the platform admin panel. This area is cross-organization and is
  # restricted to super admins (the owner of the app, not an org owner/admin).
  #
  # It always runs on the root host (no tenant subdomain), so acts_as_tenant
  # leaves a nil current tenant. We additionally wrap every action in
  # `ActsAsTenant.without_tenant` so tenant-scoped models (Customer, Deal, …)
  # can be counted across all orgs without a default scope getting in the way.
  class BaseController < ApplicationController
    layout "admin"

    before_action :require_super_admin
    around_action :ignore_tenant_scope

    private

    def require_super_admin
      unless current_user
        flash[:error] = "Please sign in to continue."
        return redirect_to new_user_session_path
      end

      # Hide the panel's existence from non-super-admins rather than flashing a
      # "not authorized" message that confirms it's there.
      raise ActiveRecord::RecordNotFound unless current_user.super_admin?
    end

    def ignore_tenant_scope(&block)
      ActsAsTenant.without_tenant(&block)
    end
  end
end
