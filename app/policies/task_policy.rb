# frozen_string_literal: true

class TaskPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      elsif user.manager?
        scope.where(user_id: [user.id] + user.associates.pluck(:id))
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
    manage_record?
  end

  def create?
    true # All authenticated users can create tasks (for self or subordinates)
  end

  def update?
    manage_record?
  end

  def destroy?
    manage_record?
  end

  def complete?
    manage_record?
  end

  private

  # Owner, admin, or manager of the task's assignee may manage it
  def manage_record?
    user.can_assign_tasks_to?(record.user)
  end
end
