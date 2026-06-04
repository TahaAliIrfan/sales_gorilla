class CreateTaxonomies < ActiveRecord::Migration[7.1]
  def change
    create_table :taxonomies do |t|
      t.references :organization, null: false, foreign_key: true
      t.string :kind, null: false
      t.string :name, null: false
      t.integer :position, null: false, default: 0
      t.boolean :archived, null: false, default: false
      t.boolean :system_default, null: false, default: false

      t.timestamps
    end

    add_index :taxonomies, [ :organization_id, :kind, :name ], unique: true
    add_index :taxonomies, [ :organization_id, :kind, :position ]
  end
end
