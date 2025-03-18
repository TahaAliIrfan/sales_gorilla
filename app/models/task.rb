class Task < ApplicationRecord
  belongs_to :user
  belongs_to :customer, optional: true
  
  # Validations
  validates :title, presence: true
  validates :due_date, presence: true
  validates :priority, inclusion: { in: %w[Low Medium High] }
  validates :status, inclusion: { in: %w[Pending In-Progress Completed Cancelled] }
  
  # Scopes
  scope :pending, -> { where(status: 'Pending') }
  scope :in_progress, -> { where(status: 'In-Progress') }
  scope :completed, -> { where(status: 'Completed') }
  scope :cancelled, -> { where(status: 'Cancelled') }
  scope :upcoming, -> { where('due_date >= ?', Time.current) }
  scope :overdue, -> { where('due_date < ? AND status NOT IN (?)', Time.current, ['Completed', 'Cancelled']) }
  scope :for_today, -> { where('due_date >= ? AND due_date <= ?', Time.current.beginning_of_day, Time.current.end_of_day) }
  scope :assigned_to, ->(user) { where(user_id: user.id) }
  
  # Constants for UI
  PRIORITIES = {
    'Low' => 'Low',
    'Medium' => 'Medium',
    'High' => 'High'
  }.freeze
  
  STATUSES = {
    'Pending' => 'Pending',
    'In-Progress' => 'In-Progress',
    'Completed' => 'Completed',
    'Cancelled' => 'Cancelled'
  }.freeze
  
  # Methods
  def complete!
    update(status: 'Completed', completed: true)
  end
  
  def pending?
    status == 'Pending'
  end
  
  def in_progress?
    status == 'In-Progress'
  end
  
  def completed?
    status == 'Completed'
  end
  
  def overdue?
    due_date < Time.current && !completed? && !cancelled?
  end
  
  def due_today?
    due_date.to_date == Date.today
  end
  
  def cancelled?
    status == 'Cancelled'
  end
end
