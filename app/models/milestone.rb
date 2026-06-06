class Milestone < ApplicationRecord
  belongs_to :customer
  belongs_to :user
  has_many :milestone_items, -> { order(:position) }, dependent: :destroy
  has_many :invoices, dependent: :restrict_with_error

  enum status: { unpaid: 'unpaid', paid: 'paid' }

  SCHEDULE_TYPES = {
    'milestone' => 'Milestone',
    'monthly' => 'Monthly'
  }.freeze

  validates :name, presence: true
  validates :total_amount, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :schedule_type, presence: true, inclusion: { in: SCHEDULE_TYPES.keys }
  validates :status, presence: true, inclusion: { in: statuses.keys }

  # enum provides .unpaid and .paid scopes automatically

  accepts_nested_attributes_for :milestone_items, allow_destroy: true, reject_if: proc { |attrs| attrs['description'].blank? && attrs['amount'].blank? }

  def mark_paid!
    update!(status: 'paid', paid_at: Time.current)
  end

  def mark_unpaid!
    update!(status: 'unpaid', paid_at: nil)
  end
end
