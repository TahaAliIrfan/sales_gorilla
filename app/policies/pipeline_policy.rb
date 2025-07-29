class PipelinePolicy < ApplicationPolicy
  def index?
    user&.admin?
  end

  def show?
    user&.admin? || user&.can_access_pipeline?(record)
  end

  def create?
    user&.admin?
  end

  def update?
    user&.admin?
  end

  def destroy?
    user&.admin?
  end

  def assign_users?
    user&.admin?
  end

  class Scope < Scope
    def resolve
      if user&.admin?
        scope.all
      else
        user.assigned_pipelines
      end
    end
  end
end