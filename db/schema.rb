# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.1].define(version: 2025_03_28_225700) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "ai_analyses", force: :cascade do |t|
    t.bigint "recording_id", null: false
    t.text "summary"
    t.integer "interest_score"
    t.text "improvement_points"
    t.text "next_steps"
    t.text "followup_message"
    t.text "followup_email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["recording_id"], name: "index_ai_analyses_on_recording_id"
  end

  create_table "customer_activities", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "user_id", null: false
    t.string "action"
    t.text "details"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_customer_activities_on_customer_id"
    t.index ["user_id"], name: "index_customer_activities_on_user_id"
  end

  create_table "customers", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "phone"
    t.text "address"
    t.string "company"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "notes"
    t.bigint "user_id"
    t.string "lead_source", default: ""
    t.string "country_code"
    t.string "linkedin_url"
    t.string "ccr_link"
    t.decimal "project_estimated_cost", precision: 10, scale: 2
    t.string "project_type", default: "Not Applicable"
    t.text "idea_description"
    t.string "status", default: "Pending"
    t.string "call_status", default: "Pending"
    t.string "email_status", default: "Pending"
    t.string "whatsapp_status", default: "Pending"
    t.string "linkedin_status", default: "Pending"
    t.string "upwork_profile", default: "Not Applicable"
    t.string "exhaust_status", default: "Not Applicable"
    t.datetime "exhaust_date"
    t.string "country"
    t.string "preferred_calling_time", default: ""
    t.string "timezone"
    t.string "platform", default: "Not Applicable"
    t.string "project_scope", default: "Not Applicable"
    t.datetime "followup_date"
    t.text "followup_notes"
    t.string "google_calendar_event_id"
    t.string "google_calendar_event_link"
    t.string "whatsapp_chat_id"
    t.index ["user_id"], name: "index_customers_on_user_id"
  end

  create_table "deal_activities", force: :cascade do |t|
    t.bigint "deal_id", null: false
    t.bigint "user_id", null: false
    t.string "action"
    t.text "details"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["deal_id"], name: "index_deal_activities_on_deal_id"
    t.index ["user_id"], name: "index_deal_activities_on_user_id"
  end

  create_table "deal_recordings", force: :cascade do |t|
    t.bigint "deal_id", null: false
    t.bigint "user_id", null: false
    t.bigint "deal_stage_id", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "recording_sid"
    t.index ["deal_id"], name: "index_deal_recordings_on_deal_id"
    t.index ["deal_stage_id"], name: "index_deal_recordings_on_deal_stage_id"
    t.index ["user_id"], name: "index_deal_recordings_on_user_id"
  end

  create_table "deal_stages", force: :cascade do |t|
    t.string "name"
    t.integer "position"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "deals", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.decimal "amount"
    t.bigint "customer_id"
    t.bigint "user_id", null: false
    t.bigint "deal_stage_id", null: false
    t.date "expected_close_date"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "closing_date"
    t.index ["customer_id"], name: "index_deals_on_customer_id"
    t.index ["deal_stage_id"], name: "index_deals_on_deal_stage_id"
    t.index ["user_id"], name: "index_deals_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.text "content"
    t.string "message_type"
    t.string "status"
    t.string "message_id"
    t.string "direction"
    t.bigint "user_id"
    t.bigint "customer_id"
    t.string "whatsapp_chat_id"
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_messages_on_customer_id"
    t.index ["direction"], name: "index_messages_on_direction"
    t.index ["message_id"], name: "index_messages_on_message_id"
    t.index ["user_id"], name: "index_messages_on_user_id"
    t.index ["whatsapp_chat_id"], name: "index_messages_on_whatsapp_chat_id"
  end

  create_table "recordings", force: :cascade do |t|
    t.string "sid"
    t.integer "duration"
    t.datetime "date"
    t.string "url"
    t.string "call_sid"
    t.bigint "user_id", null: false
    t.bigint "customer_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "transcription"
    t.string "transcription_status"
    t.index ["customer_id"], name: "index_recordings_on_customer_id"
    t.index ["user_id"], name: "index_recordings_on_user_id"
  end

  create_table "tasks", force: :cascade do |t|
    t.string "title"
    t.text "description"
    t.datetime "due_date"
    t.string "status", default: "Pending"
    t.bigint "user_id", null: false
    t.bigint "customer_id"
    t.string "priority", default: "Medium"
    t.boolean "completed", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["completed"], name: "index_tasks_on_completed"
    t.index ["customer_id"], name: "index_tasks_on_customer_id"
    t.index ["due_date"], name: "index_tasks_on_due_date"
    t.index ["status"], name: "index_tasks_on_status"
    t.index ["user_id"], name: "index_tasks_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "provider"
    t.string "uid"
    t.string "name"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "is_admin", default: false
    t.string "phone_number"
    t.string "google_token"
    t.string "google_refresh_token"
    t.datetime "google_token_expires_at"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ai_analyses", "recordings"
  add_foreign_key "customer_activities", "customers"
  add_foreign_key "customer_activities", "users"
  add_foreign_key "customers", "users"
  add_foreign_key "deal_activities", "deals"
  add_foreign_key "deal_activities", "users"
  add_foreign_key "deal_recordings", "deal_stages"
  add_foreign_key "deal_recordings", "deals"
  add_foreign_key "deal_recordings", "users"
  add_foreign_key "deals", "customers"
  add_foreign_key "deals", "deal_stages"
  add_foreign_key "deals", "users"
  add_foreign_key "messages", "customers"
  add_foreign_key "messages", "users"
  add_foreign_key "recordings", "customers"
  add_foreign_key "recordings", "users"
  add_foreign_key "tasks", "customers"
  add_foreign_key "tasks", "users"
end
