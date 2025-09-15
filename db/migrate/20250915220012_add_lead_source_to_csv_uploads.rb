class AddLeadSourceToCsvUploads < ActiveRecord::Migration[7.1]
  def change
    add_column :csv_uploads, :lead_source, :string
  end
end
