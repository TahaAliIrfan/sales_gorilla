class CustomerGroupPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      elsif user.manager?
        # Managers can see their own groups and groups from their associates
        associate_ids = user.associates.pluck(:id)
        scope.where(user_id: [ user.id ] + associate_ids)
      else
        scope.where(user: user)
      end
    end
  end

  def index?
    true
  end

  def show?
    user.admin? || record.user == user || user.manages?(record.user)
  end

  def create?
    true
  end

  def new?
    create?
  end

  def update?
    user.admin? || record.user == user
  end

  def edit?
    update?
  end

  def destroy?
    user.admin? || record.user == user
  end

  def add_customer?
    update?
  end

  def remove_customer?
    update?
  end
end
