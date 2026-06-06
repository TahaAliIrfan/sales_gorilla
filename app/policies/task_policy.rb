# frozen_string_literal: true

class TaskPolicy < ApplicationPolicy
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
    user.admin? # Only admins can see all tasks
  end
  
  def my_tasks?
    true # All users can see their own tasks
  end
  
  def show?
    user.admin? || record.user_id == user.id
  end
  
  def create?
    true # All authenticated users can create tasks
  end
  
  def update?
    user.admin? || record.user_id == user.id
  end
  
  def destroy?
    user.admin? || record.user_id == user.id
  end
  
  def complete?
    user.admin? || record.user_id == user.id
  end
end 