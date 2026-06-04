# frozen_string_literal: true

class DealPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      elsif user.manager?
        # Managers can see their own deals and deals of their associates
        associate_ids = user.associates.pluck(:id)
        scope.where(user_id: [ user.id ] + associate_ids)
      else
        scope.where(user_id: user.id)
      end
    end
  end

  def index?
    user.admin? || user.manager?
  end

  def my_deals?
    true # All authenticated users can see their own deals
  end

  def show?
    return false unless user.can_access_pipeline?(record.pipeline)
    user.admin? || record.user_id == user.id ||
    (user.manager? && user.associates.pluck(:id).include?(record.user_id))
  end

  def create?
    true # All authenticated users can create deals
  end

  def update?
    return false unless user.can_access_pipeline?(record.pipeline)
    user.admin? || record.user_id == user.id ||
    (user.manager? && user.associates.pluck(:id).include?(record.user_id))
  end

  def destroy?
    user.admin?
  end

  def update_stage?
    return false unless user.can_access_pipeline?(record.pipeline)
    user.admin? || record.user_id == user.id ||
    (user.manager? && user.associates.pluck(:id).include?(record.user_id))
  end

  def assign_user?
    user.admin? # Only admins can reassign deals
  end

  def mark_as_won?
    return false unless user.can_access_pipeline?(record.pipeline)
    user.admin? || record.user_id == user.id ||
    (user.manager? && user.associates.pluck(:id).include?(record.user_id))
  end

  def mark_as_lost?
    return false unless user.can_access_pipeline?(record.pipeline)
    user.admin? || record.user_id == user.id ||
    (user.manager? && user.associates.pluck(:id).include?(record.user_id))
  end
end
