class UserKpiRecord < ApplicationRecord
  belongs_to :user

  validates :record_date, presence: true
  validates :user_id, uniqueness: { scope: :record_date }

  scope :for_date, ->(date) { where(record_date: date) }
  scope :for_date_range, ->(start_date, end_date) { where(record_date: start_date..end_date) }
  scope :for_user, ->(user_id) { where(user_id: user_id) }

  TRACKABLE_FIELDS = %i[calls_attempted connected_calls whatsapp_messages_sent emails_sent].freeze

  def self.track!(user_id, field)
    return unless user_id.present? && TRACKABLE_FIELDS.include?(field.to_sym)

    record = find_or_create_by!(user_id: user_id, record_date: Date.current)
    record.increment!(field)
  rescue ActiveRecord::RecordNotUnique
    retry
  end

  def self.totals_for_users(user_ids, start_date, end_date)
    where(user_id: user_ids, record_date: start_date.to_date..end_date.to_date)
      .group(:user_id)
      .select(
        :user_id,
        "SUM(calls_attempted) as total_calls_attempted",
        "SUM(connected_calls) as total_connected_calls",
        "SUM(whatsapp_messages_sent) as total_whatsapp_messages_sent",
        "SUM(emails_sent) as total_emails_sent"
      )
      .index_by(&:user_id)
  end
end
