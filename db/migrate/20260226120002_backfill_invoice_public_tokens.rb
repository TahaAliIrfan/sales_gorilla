# frozen_string_literal: true

class BackfillInvoicePublicTokens < ActiveRecord::Migration[7.1]
  def up
    Invoice.where(public_token: nil).find_each do |invoice|
      loop do
        token = SecureRandom.urlsafe_base64(24).tr("-_", "").first(32)
        unless Invoice.exists?(public_token: token)
          invoice.update_column(:public_token, token)
          break
        end
      end
    end
  end

  def down
    # No need to remove tokens on rollback
  end
end
