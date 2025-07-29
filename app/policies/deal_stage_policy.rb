# frozen_string_literal: true

class DealStagePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.joins(:pipeline).where(pipelines: { id: user.assigned_pipeline_ids })
      end
    end
  end
  
  def index?
    user.admin? # Only admins can list deal stages
  end
  
  def show?
    user.admin? || user.can_access_pipeline?(record.pipeline)
  end
  
  def create?
    user.admin? # Only admins can create deal stages
  end
  
  def update?
    user.admin? # Only admins can update deal stages
  end
  
  def destroy?
    user.admin? # Only admins can delete deal stages
  end
end 