module Admin
  class UsersController < BaseController
    before_action :set_user, only: %i[show destroy]

    def index
      @users = User
                 .left_joins(:memberships)
                 .select("users.*, COUNT(memberships.id) AS memberships_count")
                 .group("users.id")
                 .order(created_at: :desc)
    end

    def show
      @memberships = @user.memberships.includes(:organization, :access_role).order(created_at: :desc)
      @stats = user_stats(@user)
    end

    def destroy
      if @user == current_user
        redirect_to admin_user_path(@user),
                    flash: { error: "You can't delete your own account from here." }
        return
      end

      unless params[:confirm_email].to_s.strip.casecmp?(@user.email.to_s.strip)
        redirect_to admin_user_path(@user),
                    flash: { error: "Confirmation text did not match the user's email. Nothing was deleted." }
        return
      end

      @user.destroy!
      redirect_to admin_users_path,
                  flash: { success: "User “#{user_label(@user)}” was deleted." }
    rescue ActiveRecord::InvalidForeignKey, ActiveRecord::RecordNotDestroyed
      blockers = user_stats(@user).select { |_, n| n.positive? }
                   .map { |label, n| "#{n} #{label}" }.join(", ")
      redirect_to admin_user_path(@user),
                  flash: { error: "Can't delete “#{user_label(@user)}” — they still own #{blockers.presence || 'related records'}. Reassign or remove those first." }
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_stats(user)
      {
        "memberships" => user.memberships.count,
        "customers"   => Customer.where(user_id: user.id).count,
        "deals"       => Deal.where(user_id: user.id).count
      }
    end

    def user_label(user)
      user.name.presence || user.email
    end
    helper_method :user_label
  end
end
