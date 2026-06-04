class CreateOrganizationsAndMemberships < ActiveRecord::Migration[7.1]
  # Tenant-scoped tables that get an organization_id column. Backfill all
  # existing rows into the default "Tecaudex" organization created here.
  TENANT_TABLES = %w[
    customers
    deals deal_stages deal_activities deal_recordings
    tasks
    recordings
    pipelines user_pipeline_assignments
    emails messages sms whatsapp_messages whatsapp_templates
    calls eleven_labs_calls
    customer_activities customer_locations customer_groups customer_group_memberships
    campaigns campaign_executions campaign_groups
    invoices invoice_line_items milestones milestone_items
    cost_estimates odoo_proposals ndas
    notifications notification_logs
    meta_conversion_logs google_meets meeting_participants
    csv_uploads
    user_kpi_records
  ].freeze

  def up
    create_table :organizations do |t|
      t.string :name, null: false
      t.string :subdomain, null: false
      t.string :primary_color, null: false, default: "#1E3A8A"
      t.string :accent_color, null: false, default: "#10B981"
      t.timestamps
    end
    add_index :organizations, :subdomain, unique: true

    create_table :memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.string :role, null: false, default: "member"
      t.timestamps
    end
    add_index :memberships, [ :user_id, :organization_id ], unique: true

    # Default organization holding all existing CRM data.
    default_org_id = execute(<<~SQL.squish).first["id"]
      INSERT INTO organizations (name, subdomain, primary_color, accent_color, created_at, updated_at)
      VALUES ('Tecaudex', 'tecaudex', '#1E3A8A', '#10B981', NOW(), NOW())
      RETURNING id
    SQL

    # Every existing user joins the default org. Existing global admins become
    # owners; existing managers/regular users become admins so they retain
    # full access inside the org.
    execute(<<~SQL.squish)
      INSERT INTO memberships (user_id, organization_id, role, created_at, updated_at)
      SELECT u.id,
             #{default_org_id},
             CASE
               WHEN EXISTS (
                 SELECT 1 FROM role_assignments ra
                 JOIN roles r ON r.id = ra.role_id
                 WHERE ra.user_id = u.id AND r.key = 'admin'
               ) THEN 'owner'
               ELSE 'admin'
             END,
             NOW(), NOW()
      FROM users u
    SQL

    TENANT_TABLES.each do |table|
      next unless table_exists?(table)

      add_reference table.to_sym, :organization, foreign_key: true, index: true
      execute "UPDATE #{table} SET organization_id = #{default_org_id} WHERE organization_id IS NULL"
      change_column_null table.to_sym, :organization_id, false
    end
  end

  def down
    TENANT_TABLES.reverse_each do |table|
      next unless table_exists?(table)
      remove_reference table.to_sym, :organization, foreign_key: true, index: true
    end
    drop_table :memberships
    drop_table :organizations
  end
end
