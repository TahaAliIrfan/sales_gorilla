# frozen_string_literal: true

class CustomerPolicy < ApplicationPolicy
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
    true # All authenticated users can list customers
  end
  
  def show?
    user.admin? || record.user_id == user.id
  end
  
  def create?
    true # All authenticated users can create customers
  end
  
  def update?
    user.admin? || record.user_id == user.id
  end
  
  def destroy?
    user.admin?
  end
  
  def update_status?
    user.admin? || record.user_id == user.id
  end

  def update_communication_status?
    user.admin? || record.user_id == user.id
  end

  def whatsapp_messages?
    user.admin? || record.user_id == user.id
  end
  
  def send_whatsapp_text?
    user.admin? || record.user_id == user.id
  end
  
  def send_whatsapp_media?
    user.admin? || record.user_id == user.id
  end
  
  def bulk_assign?
    user.admin?
  end
end 