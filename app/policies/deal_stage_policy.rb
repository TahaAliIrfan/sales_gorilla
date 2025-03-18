# frozen_string_literal: true

class DealStagePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.all # Deal stages are visible to all users
    end
  end
  
  def index?
    true # All authenticated users can list deal stages
  end
  
  def show?
    true # All authenticated users can view deal stages
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