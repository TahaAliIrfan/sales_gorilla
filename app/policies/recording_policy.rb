class RecordingPolicy < ApplicationPolicy
  def index?
    true # Everyone can access the index, but the controller will filter results
  end

  def show?
    user.admin? || record.user_id == user.id || 
    (user.manager? && user.associates.pluck(:id).include?(record.user_id))
  end

  def download?
    show?
  end

  def transcript?
    show?
  end

  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      elsif user.manager?
        # Managers can see their own recordings and recordings of their associates
        associate_ids = user.associates.pluck(:id)
        scope.where(user_id: [user.id] + associate_ids)
      else
        scope.where(user_id: user.id)
      end
    end
  end
end 