class CampaignPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      elsif user.manager?
        # Managers can see their own campaigns and campaigns from their associates
        associate_ids = user.associates.pluck(:id)
        scope.where(user_id: [user.id] + associate_ids)
      else
        scope.where(user: user)
      end
    end
  end

  def index?
    true
  end

  def show?
    user.admin? || record.user == user || user.manages?(record.user) || record.user == nil
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

  def send_now?
    user.admin? || (record.user == user && record.draft?)
  end

  def schedule?
    user.admin? || (record.user == user && record.draft?)
  end

  def restart?
    user.admin? || (record.user == user && (record.completed? || record.failed? || record.stopped?))
  end

  def stop?
    user.admin? || (record.user == user && (record.scheduled? || record.in_progress?))
  end

  def add_customers?
    update?
  end

  def remove_customer?
    update?
  end
end
