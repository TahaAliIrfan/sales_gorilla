class RecordingPolicy < ApplicationPolicy
  def index?
    true # Everyone can access the index, but the controller will filter results
  end

  def show?
    user.admin? || record.user_id == user.id
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
      else
        scope.where(user_id: user.id)
      end
    end
  end
end 