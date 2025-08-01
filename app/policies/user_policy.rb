class UserPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.where(id: user.id)
      end
    end
  end

  def index?
    user.admin? || user.manager?
  end

  def show?
    user.admin? || record == user || (user.manager? && user.associates.include?(record))
  end

  def create?
    user.admin?
  end

  def update?
    user.admin? || record == user
  end

  def destroy?
    user.admin? && record != user
  end

  def update_fcm_token?
    # Users can update their own FCM token, admins can update any user's FCM token
    user.admin? || record == user
  end
end