# frozen_string_literal: true

class CustomerPolicy < ApplicationPolicy
  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      elsif user.manager?
        # Managers can see their own customers, customers of their associates, and unassigned customers
        associate_ids = user.associates.pluck(:id)
        scope.where(user_id: [user.id] + associate_ids + [nil])
      else
        # Associates can see their own customers and unassigned customers
        scope.where(user_id: [user.id, nil])
      end
    end
  end
  
  def index?
    true # All authenticated users can list customers
  end
  
  def show?
    user.admin? || record.user_id == user.id || 
    (user.manager? && user.associates.pluck(:id).include?(record.user_id))
  end
  
  def create?
    true # All authenticated users can create customers
  end
  
  def update?
    user.admin? || record.user_id == user.id || 
    (user.manager? && user.associates.pluck(:id).include?(record.user_id))
  end

  def analyze_phone?
    user.admin? || record.user_id == user.id ||
      (user.manager? && user.associates.pluck(:id).include?(record.user_id))
  end

  def destroy?
    user.admin?
  end

  def remove_document?
    user.admin? || record.user_id == user.id ||
    (user.manager? && user.associates.pluck(:id).include?(record.user_id))
  end

  def update_status?
    user.admin? || record.user_id == user.id ||
    (user.manager? && user.associates.pluck(:id).include?(record.user_id))
  end

  def update_communication_status?
    user.admin? || record.user_id == user.id ||
    (user.manager? && user.associates.pluck(:id).include?(record.user_id))
  end

  def whatsapp_messages?
    user.admin? || record.user_id == user.id ||
    (user.manager? && user.associates.pluck(:id).include?(record.user_id))
  end

  def send_whatsapp_text?
    user.admin? || record.user_id == user.id ||
    (user.manager? && user.associates.pluck(:id).include?(record.user_id))
  end

  def send_whatsapp_media?
    user.admin? || record.user_id == user.id || 
    (user.manager? && user.associates.pluck(:id).include?(record.user_id))
  end

  def calculate_lead_score?
    true
  end
  
  def bulk_assign?
    user.admin? || user.manager?
  end
  
  def bulk_status_change?
    user.admin? || user.manager?
  end

  def assign_to_self?
    # Allow any user to assign unassigned customers to themselves
    record.user_id.nil?
  end

  def mark_lead_quality?
    # Only admins can mark lead quality for Google Ads offline conversions
    user.admin?
  end
end