class Customer < ApplicationRecord
  belongs_to :user, optional: true
  has_many :deals
  has_many :recordings, dependent: :nullify
  
  validates :name, presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false }, 
            format: { with: URI::MailTo::EMAIL_REGEXP, message: "must be a valid email address" }
  validates :phone, presence: true
  
  before_validation :normalize_email
  
  # Scopes
  scope :assigned_to, ->(user_id) { where(user_id: user_id) if user_id.present? }
  scope :search, ->(term) {
    if term.present?
      term = "%#{term.downcase}%"
      where(
        "LOWER(name) LIKE ? OR LOWER(email) LIKE ? OR LOWER(phone) LIKE ? OR LOWER(company) LIKE ?",
        term, term, term, term
      )
    end
  }
  
  private
  
  def normalize_email
    self.email = email.downcase.strip if email.present?
  end
end
