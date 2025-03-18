class Task < ApplicationRecord
  belongs_to :user
  belongs_to :customer, optional: true

  enum status: { pending: 0, in_progress: 1, completed: 2, cancelled: 3 }, _prefix: true

  validates :title, presence: true
  validates :due_date, presence: true
  validates :priority, inclusion: { in: %w[Low Medium High] }

  scope :pending, -> { where(status: :pending) }
  scope :in_progress, -> { where(status: :in_progress) }
  scope :completed, -> { where(status: :completed) }
  scope :cancelled, -> { where(status: :cancelled) }
  scope :upcoming, -> { where('due_date >= ?', Date.today) }
  scope :overdue, -> { where('due_date < ?', Date.today).pending }
  scope :for_today, -> { where('due_date >= ? AND due_date <= ?', Date.today.beginning_of_day, Date.today.end_of_day).pending }
  scope :assigned_to, ->(user) { where(user_id: user.id) }

  PRIORITIES = {
    'Low' => 'Low',
    'Medium' => 'Medium',
    'High' => 'High'
  }.freeze
  
  STATUSES = {
    'pending' => 'Pending',
    'in_progress' => 'In Progress',
    'completed' => 'Completed',
    'cancelled' => 'Cancelled'
  }.freeze

  def complete!
    update(status: :completed)
  end
  
  def pending?
    status == 'pending'
  end
  
  def in_progress?
    status == 'in_progress'
  end
  
  def completed?
    status == 'completed'
  end
  
  def overdue?
    due_date.to_date < Date.today && !completed? && !cancelled?
  end
  
  def due_today?
    due_date.to_date == Date.today
  end
  
  def cancelled?
    status == 'cancelled'
  end
  
  # Get formatted status for display
  def status_display
    STATUSES[status]
  end
end
