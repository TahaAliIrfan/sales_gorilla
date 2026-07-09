class Invoice < ApplicationRecord
  belongs_to :customer
  belongs_to :milestone
  belongs_to :user
  belongs_to :bank_account, optional: true
  has_many :invoice_line_items, -> { order(:position) }, dependent: :destroy
  has_many :invoice_payment_links, -> { order(:position) }, dependent: :destroy
  has_one_attached :pdf_file
  has_one_attached :payment_proof

  enum status: { pending: 'pending', paid: 'paid' }

  validates :invoice_number, presence: true, uniqueness: true
  validates :issue_date, presence: true
  validates :due_date, presence: true
  validates :total, presence: true, numericality: { greater_than_or_equal_to: 0 }

  accepts_nested_attributes_for :invoice_line_items, allow_destroy: true
  accepts_nested_attributes_for :invoice_payment_links, allow_destroy: true,
    reject_if: ->(attrs) { attrs[:url].blank? && attrs[:label].blank? }

  before_validation :set_invoice_number, on: :create
  before_validation :set_public_token, on: :create
  before_validation :recalculate_totals

  def publicly_viewable?
    pending? && !expired?
  end

  def expired?
    due_date < Date.current
  end

  def subtotal
    invoice_line_items.map(&:amount).compact.sum
  end

  def self.next_invoice_number
    year = Date.current.year
    count = where("invoice_number LIKE ?", "INV-#{year}-%").count + 1
    "INV-#{year}-#{count.to_s.rjust(5, '0')}"
  end

  def populate_from_milestone!(milestone)
    milestone.milestone_items.each_with_index do |item, index|
      invoice_line_items.build(
        description: item.description,
        amount: item.amount,
        position: index,
        milestone_item_id: item.id
      )
    end
  end

  private

  def set_invoice_number
    self.invoice_number ||= self.class.next_invoice_number
  end

  def set_public_token
    return if public_token.present?
    return unless Invoice.column_names.include?("public_token")
    loop do
      self.public_token = SecureRandom.urlsafe_base64(24).tr("-_", "").first(32)
      break unless self.class.exists?(public_token: public_token)
    end
  end

  def recalculate_totals
    return if invoice_line_items.empty?

    st = invoice_line_items.map(&:amount).compact.sum
    self.tax_amount = st * (tax_rate.to_f / 100)
    self.total = st + tax_amount
  end
end
