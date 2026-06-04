# A per-organization editable list of values used by a Customer attribute:
# lead_source, status, call_status, email_status, whatsapp_status,
# linkedin_status, exhaust_status, or project_type. Replaces the hardcoded
# constants in Customer so admins can add / rename / delete / reorder values
# through Settings > Taxonomies without code changes.
#
# Customer columns still store STRINGS (no foreign keys), so existing reports
# and search filters keep working. Validation just consults the org's
# Taxonomy rows.
class Taxonomy < ApplicationRecord
  KINDS = %w[
    lead_source
    customer_status
    call_status
    email_status
    whatsapp_status
    linkedin_status
    exhaust_status
    project_type
  ].freeze

  # Human-readable labels for the Settings UI.
  KIND_LABELS = {
    "lead_source"      => "Lead sources",
    "customer_status"  => "Customer statuses",
    "call_status"      => "Call statuses",
    "email_status"     => "Email statuses",
    "whatsapp_status"  => "WhatsApp statuses",
    "linkedin_status"  => "LinkedIn statuses",
    "exhaust_status"   => "Exhaust statuses",
    "project_type"     => "Project types"
  }.freeze

  # Which Customer column each kind binds to. Used by the cascade service
  # to update referencing records when an admin renames or deletes a value.
  CUSTOMER_COLUMN = {
    "lead_source"      => :lead_source,
    "customer_status"  => :status,
    "call_status"      => :call_status,
    "email_status"     => :email_status,
    "whatsapp_status"  => :whatsapp_status,
    "linkedin_status"  => :linkedin_status,
    "exhaust_status"   => :exhaust_status,
    "project_type"     => :project_type
  }.freeze

  belongs_to :organization
  acts_as_tenant :organization

  validates :kind, presence: true, inclusion: { in: KINDS }
  validates :name, presence: true,
                   uniqueness: { scope: %i[organization_id kind], case_sensitive: false }
  validates :position, presence: true, numericality: { only_integer: true }

  scope :for_kind, ->(kind) { where(kind: kind.to_s) }
  scope :active,   -> { where(archived: false) }
  scope :ordered,  -> { order(position: :asc, id: :asc) }

  before_validation :set_position, on: :create

  # Convenience: all active values for a kind, in display order. Used by every
  # dropdown that used to read from Customer::LEAD_SOURCES etc.
  def self.values_for(kind)
    for_kind(kind).active.ordered.pluck(:name)
  end

  # Same data shaped for `options_for_select` ([label, value] pairs).
  def self.options_for(kind)
    for_kind(kind).active.ordered.pluck(:name).map { |n| [ n, n ] }
  end

  private

  def set_position
    return if position.present? && position.positive?

    last = self.class.where(organization_id: organization_id, kind: kind).maximum(:position).to_i
    self.position = last + 1
  end
end
