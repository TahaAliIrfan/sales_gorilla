# frozen_string_literal: true

class DealPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      else
        scope.where(user_id: user.id)
      end
    end
  end
  
  def index?
    user.admin?
  end
  
  def my_deals?
    true # All authenticated users can see their own deals
  end
  
  def show?
    user.admin? || record.user_id == user.id
  end
  
  def create?
    true # All authenticated users can create deals
  end
  
  def update?
    user.admin? || record.user_id == user.id
  end
  
  def destroy?
    user.admin?
  end
  
  def update_stage?
    user.admin? || record.user_id == user.id
  end
  
  def assign_user?
    user.admin? # Only admins can reassign deals
  end
  
  def mark_as_won?
    user.admin? || record.user_id == user.id
  end
  
  def mark_as_lost?
    user.admin? || record.user_id == user.id
  end
end 