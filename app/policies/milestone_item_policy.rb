# frozen_string_literal: true

class MilestoneItemPolicy < ApplicationPolicy
  def create?
    milestone_accessible?
  end

  def update?
    milestone_accessible?
  end

  private

  def milestone_accessible?
    return false unless record.respond_to?(:milestone)
    milestone = record.milestone
    MilestonePolicy.new(user, milestone).show?
  end
end
