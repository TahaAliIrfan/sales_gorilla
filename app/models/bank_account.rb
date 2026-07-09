class BankAccount < ApplicationRecord
  has_many :invoices, dependent: :nullify

  validates :label, presence: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :label) }

  # Ordered [label, value] pairs of the populated detail fields, so the UI and
  # PDF can render whatever a given country's account provides (UK sort code,
  # US routing number, AUS BSB, etc.) without hardcoding per-country layouts.
  def detail_fields
    [
      ["Bank name", bank_name],
      ["Bank address", bank_address],
      ["Beneficiary name", beneficiary_name],
      ["Account number", account_number],
      ["Sort code", sort_code],
      ["Routing number", routing_number],
      ["BSB", bsb],
      ["IBAN", iban],
      ["SWIFT / BIC", swift_bic],
      ["Additional info", additional_info]
    ].select { |_label, value| value.present? }
  end
end
