class User < ApplicationRecord
  # Devise modules. database_authenticatable enables email+password sign-in,
  # which coexists with the existing Google OAuth flow (sessions_controller).
  # Validatable is skipped because legacy OAuth-only rows may have been
  # created without an email; we enforce email/password validations ourselves
  # only when a password is set.
  devise :database_authenticatable, :registerable, :recoverable, :rememberable, :trackable

  validates :email, presence: true, uniqueness: { case_sensitive: false },
            format: { with: URI::MailTo::EMAIL_REGEXP },
            if: -> { encrypted_password.present? || will_save_change_to_encrypted_password? }
  validates :password, length: { minimum: 8 },
            if: -> { password.present? }

  # Organization memberships (Slack/Notion-style: one global user, many orgs).
  has_many :memberships, dependent: :destroy
  has_many :organizations, through: :memberships

  has_many :deals
  has_many :deal_activities
  has_many :deal_recordings
  has_many :customers
  has_many :recordings
  has_many :tasks, dependent: :nullify
  has_many :messages, dependent: :nullify
  has_many :notifications, dependent: :destroy
  has_many :cost_estimates, dependent: :destroy
  has_many :odoo_proposals, dependent: :destroy
  has_many :user_kpi_records, dependent: :destroy

  # Pipeline assignments
  has_many :user_pipeline_assignments, dependent: :destroy
  has_many :assigned_pipelines, through: :user_pipeline_assignments, source: :pipeline

  # Campaign relationships
  has_many :customer_groups, dependent: :destroy
  has_many :campaigns, dependent: :destroy

  # Validate phone number format
  validates :phone_number, format: { with: /\A\+\d{6,15}\z/, message: "must be a valid phone number with country code (e.g. +923001234567)", allow_blank: true }

  # Scopes
  scope :active_users, -> { where(active: true) }
  scope :inactive_users, -> { where(active: false) }

  # Check if phone number is set
  def phone_number_set?
    phone_number.present?
  end

  def member_of?(organization)
    memberships.exists?(organization_id: organization.id)
  end

  def membership_for(organization)
    memberships.find_by(organization_id: organization.id)
  end

  # User activation methods
  def activate!
    update(active: true)
  end

  def deactivate!
    update(active: false)
  end

  def active?
    active == true
  end

  def inactive?
    !active?
  end

  # ---- Per-organization roles & hierarchy (membership-based) --------------
  # These replace the retired global Role/RoleAssignment system. They resolve
  # against the active tenant (ActsAsTenant.current_tenant) by default, so the
  # existing call sites (current_user.admin?, .associates, …) become org-aware
  # without changes. When no tenant is set (background jobs, console) the
  # capability predicates fall back to "in ANY org".

  # The membership for the active tenant (or a specified org).
  def org_membership(org = ActsAsTenant.current_tenant)
    org && membership_for(org)
  end

  # Per-org capability role record. Has #key / #name / #hierarchy_level /
  # #outranks? — preserves the old highest_role contract for views.
  def primary_role(org = ActsAsTenant.current_tenant)
    org_membership(org)&.access_role
  end
  alias_method :highest_role, :primary_role

  # Maps the per-org role to the legacy {admin,manager,associate} vocabulary
  # for the v2 API and `case role.key` call sites. Falls back to the user's
  # highest-privilege membership when no tenant is active (e.g. at sign-in).
  LEGACY_ROLE_MAP = {
    "owner" => "admin", "admin" => "admin", "manager" => "manager",
    "member" => "associate", "viewer" => "associate"
  }.freeze

  def legacy_role_key(org = ActsAsTenant.current_tenant)
    role = primary_role(org) || best_membership_role
    LEGACY_ROLE_MAP[role&.key] || "associate"
  end

  def best_membership_role
    memberships.joins(:access_role).order("roles.hierarchy_level DESC").first&.access_role
  end

  # Admin-equivalent: can administer the org (owner or admin).
  def admin?(org = ActsAsTenant.current_tenant)
    if org
      org_membership(org)&.can?("org.administer") || false
    else
      memberships.joins(:access_role).where(roles: { key: %w[owner admin] }).exists?
    end
  end

  def owner?(org = ActsAsTenant.current_tenant)
    primary_role(org)&.key == "owner"
  end

  def manager?(org = ActsAsTenant.current_tenant)
    if org
      primary_role(org)&.key == "manager"
    else
      memberships.joins(:access_role).where(roles: { key: "manager" }).exists?
    end
  end

  # Set (or create) this user's capability role in an org. Used by the user
  # management screen and the sign-in auto-promotion of internal admins.
  def grant_org_role!(organization, role_key)
    return false unless organization
    role_key = role_key.to_s
    membership = membership_for(organization) || memberships.build(organization: organization)
    membership.access_role = organization.roles.system_roles.find_by(key: role_key)
    membership.role = role_key if Membership::ROLES.include?(role_key)
    membership.save!
    membership
  end

  # ---- Manager hierarchy (reports_to) -------------------------------------

  # Direct reports of this user within the active org.
  def associates(org = ActsAsTenant.current_tenant)
    membership = org_membership(org)
    return User.none unless membership
    User.where(id: membership.direct_reports.select(:user_id))
  end
  alias_method :managed_associates, :associates

  # Make `associate` report to this user within the org.
  def assign_associate(associate, org: ActsAsTenant.current_tenant, assigned_by: nil)
    return false unless org && associate.is_a?(User)
    manager_m = org_membership(org)
    assoc_m   = associate.membership_for(org)
    return false unless manager_m && assoc_m

    assoc_m.update(reports_to: manager_m)
  end

  # Detach `associate` from reporting to this user.
  def remove_associate(associate, org: ActsAsTenant.current_tenant)
    return false unless org && associate.is_a?(User)
    manager_m = org_membership(org)
    assoc_m   = associate.membership_for(org)
    return false unless manager_m && assoc_m && assoc_m.reports_to_id == manager_m.id

    assoc_m.update(reports_to_id: nil)
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
        priority: "Medium",
        status: "pending"
      )

      true
    else
      false
    end
  end

  # Resource access methods for role-based authorization

  # Can user access recordings for a given user (within the active org)?
  def can_access_recordings_for?(target_user, org = ActsAsTenant.current_tenant)
    return true if self == target_user
    return true if admin?(org)
    manager?(org) && associates(org).exists?(id: target_user.id)
  end

  # Can user access customers for a given user (within the active org)?
  def can_access_customers_for?(target_user, org = ActsAsTenant.current_tenant)
    return true if self == target_user
    return true if admin?(org)
    manager?(org) && associates(org).exists?(id: target_user.id)
  end

  # Can this user assign the given role within the org? Owners may assign any
  # role; admins/user-managers may assign anything except owner.
  def can_assign_role?(role_key, org = ActsAsTenant.current_tenant)
    key = role_key.respond_to?(:key) ? role_key.key : role_key.to_s
    membership = org_membership(org)
    return false unless membership
    return true if membership.access_role&.key == "owner"
    membership.can?("users.manage") && key != "owner"
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
