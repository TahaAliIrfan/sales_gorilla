class CreateCsvUploads < ActiveRecord::Migration[7.1]
  def change
    create_table :csv_uploads do |t|
      t.string :upload_token
      t.references :user, null: false, foreign_key: true
      t.string :original_filename
      t.string :file_path
      t.text :headers
      t.text :sample_rows
      t.text :suggested_mappings
      t.integer :total_rows
      t.string :status

      t.timestamps
    end
    add_index :csv_uploads, :upload_token, unique: true
  end
end
