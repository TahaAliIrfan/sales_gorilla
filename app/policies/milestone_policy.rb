# frozen_string_literal: true

class MilestonePolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      scope.joins(:customer).merge(CustomerPolicy::Scope.new(user, Customer).resolve)
    end
  end

  def index?
    customer_accessible?
  end

  def show?
    customer_accessible?
  end

  def create?
    customer_accessible?
  end

  def update?
    customer_accessible?
  end

  def destroy?
    customer_accessible?
  end

  def mark_paid?
    customer_accessible?
  end

  def mark_unpaid?
    customer_accessible?
  end

  private

  def customer_accessible?
    return false unless record.respond_to?(:customer)
    customer = record.customer
    user.admin? || customer.user_id == user.id ||
      (user.manager? && user.associates.pluck(:id).include?(customer.user_id))
  end
end
