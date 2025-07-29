class User < ApplicationRecord
  has_many :deals
  has_many :deal_activities
  has_many :deal_recordings
  has_many :customers
  has_many :recordings
  has_many :tasks, dependent: :nullify
  has_many :messages, dependent: :nullify
  has_many :notifications, dependent: :destroy
  
  # Pipeline assignments
  has_many :user_pipeline_assignments, dependent: :destroy
  has_many :assigned_pipelines, through: :user_pipeline_assignments, source: :pipeline
  
  # Role relationships
  has_many :role_assignments, dependent: :destroy
  has_many :roles, through: :role_assignments
  has_many :assigned_roles, class_name: 'RoleAssignment', foreign_key: 'assigned_by_id'
  
  # Associate relationships 
  has_many :manager_assignments, -> { where(role: Role.associate) }, class_name: 'RoleAssignment', foreign_key: 'assigned_by_id'
  has_many :associates, through: :manager_assignments, source: :user

  # Validate phone number format
  validates :phone_number, format: { with: /\A\+\d{6,15}\z/, message: "must be a valid phone number with country code (e.g. +923001234567)", allow_blank: true }

  # Check if phone number is set
  def phone_number_set?
    phone_number.present?
  end

  # Role methods

  # Assign a role to user
  def assign_role(role_key, assigned_by: nil, resource: nil)
    role = role_key.is_a?(Role) ? role_key : Role.find_by(key: role_key.to_s)
    return false unless role

    role_assignments.create(
      role: role,
      assigned_by: assigned_by,
      resource: resource
    )
  end

  # Remove a role from user
  def remove_role(role_key, resource: nil)
    role = role_key.is_a?(Role) ? role_key : Role.find_by(key: role_key.to_s)
    return false unless role

    assignment = role_assignments.find_by(role: role, resource: resource)
    assignment&.destroy.present?
  end

  # Check if user has a specific role
  def has_role?(role_key, resource: nil)
    role = role_key.is_a?(Role) ? role_key : Role.find_by(key: role_key.to_s)
    return false unless role

    if resource
      role_assignments.exists?(role: role, resource: resource)
    else
      role_assignments.exists?(role: role)
    end
  end

  # Get highest role based on hierarchy_level
  def highest_role
    roles.order(hierarchy_level: :desc).first
  end

  # Admin methods - based solely on roles
  def admin?
    has_role?(:admin)
  end

  # Method to make a user an admin
  def make_admin!(assigned_by: nil)
    assign_role(:admin, assigned_by: assigned_by)
  end

  # Method to revoke admin privileges
  def revoke_admin!
    remove_role(:admin)
  end

  # Manager methods
  def manager?
    has_role?(:manager)
  end

  # Make user a manager
  def make_manager!(assigned_by: nil)
    assign_role(:manager, assigned_by: assigned_by)
  end

  # Revoke manager role
  def revoke_manager!
    remove_role(:manager)
  end

  # Associate-Manager Assignment methods

  # Assign an associate to a manager
  # This method is used by admins to establish manager-associate relationships
  def assign_associate(associate, assigned_by: nil)
    return false unless manager?
    return false unless associate.is_a?(User)

    # Ensure the user has associate role
    unless associate.has_role?(:associate)
      associate.assign_role(:associate, assigned_by: assigned_by || self)
    end

    # Create the relationship by assigning the associate role with the manager as assigned_by
    associate_role = Role.associate

    # Check if this manager is already managing this associate
    existing = RoleAssignment.where(
      user: associate,
      role: associate_role,
      assigned_by: self
    ).first

    # If relationship exists, return true
    return true if existing.present?

    # Create new relationship
    existing_role =  RoleAssignment.find_by(user: associate, role: associate_role)

    if existing_role.present?
      existing_role.update(assigned_by: self)
    else
      RoleAssignment.create(
        user: associate,
        role: associate_role,
        assigned_by: self
      )
    end
  end

  # Remove an associate from a manager
  def remove_associate(associate)
    return false unless manager?
    return false unless associate.is_a?(User)
    
    # Find and destroy the role assignment
    assignment = RoleAssignment.find_by(
      user: associate,
      role: Role.associate,
      assigned_by: self
    )
    
    assignment&.destroy.present?
  end
  
  # Associate methods - get all users who are associates of this manager
  def managed_associates
    return User.none unless manager? || admin?
    User.joins(:role_assignments)
        .where(role_assignments: { role: Role.associate })
  end
  
  # Get all managers of this user
  def managers
    User.joins(:role_assignments)
        .where(role_assignments: { 
          role: Role.manager,
          assigned_by_id: RoleAssignment.where(user: self, role: Role.associate).select(:assigned_by_id)
        })
        .distinct
  end
  
  # Task methods
  def pending_tasks
    tasks.pending
  end
  
  def tasks_for_today
    tasks.for_today
  end
  
  def overdue_tasks
    tasks.overdue
  end
  
  # Notification methods
  def unread_notifications_count
    notifications.unread.count
  end
  
  def recent_notifications(limit = 10)
    notifications.recent.limit(limit)
  end
  
  def mark_all_notifications_as_read!
    notifications.unread.update_all(read: true)
  end
  
  # Google Calendar methods
  def google_auth_configured?
    google_token.present? && google_refresh_token.present?
  end
  
  def schedule_customer_followup(customer, followup_date, notes)
    return false unless google_auth_configured?
    
    # Create a Google Calendar event
    calendar_service = GoogleCalendarService.new(self)
    result = calendar_service.create_customer_followup_event(customer, followup_date, notes)
    
    if result[:success]
      customer.update(
        followup_date: followup_date,
        followup_notes: notes,
        google_calendar_event_id: result[:event_id],
        google_calendar_event_link: result[:html_link]
      )
      
      # Create a task for the follow-up
      Task.create!(
        user: self,
        customer: customer,
        title: "Follow up with #{customer.name}",
        description: notes,
        due_date: followup_date,
        priority: 'Medium',
        status: 'pending'
      )
      
      true
    else
      false
    end
  end
  
  # Resource access methods for role-based authorization
  
  # Can user access recordings for a given user?
  def can_access_recordings_for?(target_user)
    return true if admin?
    return true if self == target_user
    return true if manager? && associates.include?(target_user)
    false
  end
  
  # Can user access customers for a given user?
  def can_access_customers_for?(target_user)
    return true if admin?
    return true if self == target_user
    return true if manager? && associates.include?(target_user)
    false
  end
  
  # Can user assign roles?
  def can_assign_role?(role_key)
    role = role_key.is_a?(Role) ? role_key : Role.find_by(key: role_key.to_s)
    return false unless role
    
    admin? || (highest_role && highest_role.outranks?(role))
  end
  
  # Pipeline access methods
  def assigned_pipeline_ids
    assigned_pipelines.pluck(:id)
  end
  
  def can_access_pipeline?(pipeline)
    return true if admin?
    assigned_pipelines.include?(pipeline)
  end
  
  def accessible_deals
    return Deal.all if admin?
    Deal.for_user_pipeline(self)
  end
  
  def accessible_deal_stages
    return DealStage.all if admin?
    
    # If user has no pipeline assignments, return empty relation
    pipeline_ids = assigned_pipeline_ids
    return DealStage.none if pipeline_ids.empty?
    
    DealStage.joins(:pipeline).where(pipelines: { id: pipeline_ids, active: true })
  end
end
