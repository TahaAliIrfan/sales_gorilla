module Admin
  class DashboardController < BaseController
    def index
      @organizations_count = Organization.count
      @users_count         = User.count
      @super_admins_count  = User.where(super_admin: true).count
      @customers_count     = Customer.count

      @recent_organizations = Organization.order(created_at: :desc).limit(5)
      @recent_users         = User.order(created_at: :desc).limit(5)
    end
  end
end
