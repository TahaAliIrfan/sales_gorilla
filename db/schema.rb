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

ActiveRecord::Schema[7.1].define(version: 2025_09_10_233532) do
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

  create_table "ai_conversations", force: :cascade do |t|
    t.string "conversation_id", null: false
    t.string "status"
    t.integer "duration_seconds"
    t.string "agent_id"
    t.string "call_from"
    t.string "call_to"
    t.datetime "conversation_date"
    t.jsonb "transcript"
    t.jsonb "raw_data"
    t.bigint "user_id"
    t.bigint "customer_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_date"], name: "index_ai_conversations_on_conversation_date"
    t.index ["conversation_id"], name: "index_ai_conversations_on_conversation_id", unique: true
    t.index ["customer_id"], name: "index_ai_conversations_on_customer_id"
    t.index ["status"], name: "index_ai_conversations_on_status"
    t.index ["user_id"], name: "index_ai_conversations_on_user_id"
  end

  create_table "cost_estimates", force: :cascade do |t|
    t.string "app_type"
    t.text "description"
    t.text "features_json"
    t.integer "total_hours"
    t.decimal "hourly_rate"
    t.decimal "total_cost"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "scale"
    t.index ["user_id"], name: "index_cost_estimates_on_user_id"
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

  create_table "customer_locations", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "formatted_number"
    t.string "national_format"
    t.string "country_code"
    t.string "area_code"
    t.string "phone_type"
    t.string "country_iso"
    t.string "country_name"
    t.string "state_province"
    t.string "city"
    t.string "region"
    t.string "geo_name"
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.string "timezone"
    t.string "timezone_abbreviation"
    t.decimal "timezone_offset", precision: 4, scale: 2
    t.boolean "dst_active", default: false
    t.string "preferred_calling_time"
    t.string "carrier"
    t.string "line_type"
    t.string "network_operator"
    t.string "analysis_version", default: "2.0"
    t.datetime "analyzed_at"
    t.string "data_source"
    t.json "raw_analysis_data"
    t.integer "location_confidence", default: 0
    t.integer "timezone_confidence", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["analysis_version"], name: "index_customer_locations_on_analysis_version"
    t.index ["analyzed_at"], name: "index_customer_locations_on_analyzed_at"
    t.index ["area_code"], name: "index_customer_locations_on_area_code"
    t.index ["carrier"], name: "index_customer_locations_on_carrier"
    t.index ["city"], name: "index_customer_locations_on_city"
    t.index ["country_iso"], name: "index_customer_locations_on_country_iso"
    t.index ["customer_id"], name: "index_customer_locations_on_customer_id", unique: true
    t.index ["latitude", "longitude"], name: "index_customer_locations_on_coordinates"
    t.index ["state_province"], name: "index_customer_locations_on_state_province"
    t.index ["timezone"], name: "index_customer_locations_on_timezone"
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
    t.datetime "last_email_fetched_at"
    t.string "customer_type", default: "Standard"
    t.string "meta_lead_id"
    t.string "facebook_click_id"
    t.string "browser_id"
    t.string "meta_campaign_id"
    t.string "meta_adset_id"
    t.string "meta_ad_id"
    t.text "meta_events_sent"
    t.datetime "last_meta_event_sent_at"
    t.integer "lead_score"
    t.integer "geographic_score"
    t.integer "description_score"
    t.datetime "lead_score_updated_at"
    t.index ["browser_id"], name: "index_customers_on_browser_id"
    t.index ["facebook_click_id"], name: "index_customers_on_facebook_click_id"
    t.index ["meta_lead_id"], name: "index_customers_on_meta_lead_id"
    t.index ["user_id"], name: "index_customers_on_user_id"
    t.index ["whatsapp_chat_id"], name: "index_customers_on_whatsapp_chat_id"
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
    t.bigint "pipeline_id", null: false
    t.boolean "active", default: true
    t.index ["pipeline_id"], name: "index_deal_stages_on_pipeline_id"
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

  create_table "eleven_labs_calls", force: :cascade do |t|
    t.string "call_id", null: false
    t.string "to_number", null: false
    t.string "status", default: "initiated", null: false
    t.integer "duration"
    t.datetime "started_at"
    t.datetime "ended_at"
    t.bigint "customer_id", null: false
    t.bigint "user_id", null: false
    t.text "response_data"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "transcription"
    t.index ["call_id"], name: "index_eleven_labs_calls_on_call_id", unique: true
    t.index ["created_at"], name: "index_eleven_labs_calls_on_created_at"
    t.index ["customer_id"], name: "index_eleven_labs_calls_on_customer_id"
    t.index ["status"], name: "index_eleven_labs_calls_on_status"
    t.index ["user_id"], name: "index_eleven_labs_calls_on_user_id"
  end

  create_table "email_attachments", force: :cascade do |t|
    t.bigint "email_id", null: false
    t.string "filename"
    t.string "content_type"
    t.string "attachment_id"
    t.integer "size"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_id"], name: "index_email_attachments_on_email_id"
  end

  create_table "emails", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "user_id", null: false
    t.string "message_id"
    t.string "gmail_thread_id"
    t.string "subject"
    t.text "body_html"
    t.text "body_text"
    t.string "from_email"
    t.string "from_name"
    t.string "to_email"
    t.string "to_name"
    t.string "status"
    t.datetime "sent_at"
    t.datetime "received_at"
    t.datetime "read_at"
    t.boolean "has_attachments"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "snippet"
    t.string "label_ids"
    t.index ["customer_id"], name: "index_emails_on_customer_id"
    t.index ["label_ids"], name: "index_emails_on_label_ids"
    t.index ["message_id"], name: "index_emails_on_message_id"
    t.index ["user_id"], name: "index_emails_on_user_id"
  end

  create_table "google_meets", force: :cascade do |t|
    t.string "title", null: false
    t.string "meeting_link", null: false
    t.datetime "start_time", null: false
    t.datetime "end_time"
    t.integer "status", default: 0
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["start_time"], name: "index_google_meets_on_start_time"
    t.index ["status"], name: "index_google_meets_on_status"
    t.index ["user_id"], name: "index_google_meets_on_user_id"
  end

  create_table "meeting_participants", force: :cascade do |t|
    t.bigint "google_meet_id", null: false
    t.bigint "user_id", null: false
    t.integer "role", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["google_meet_id", "user_id"], name: "index_meeting_participants_on_google_meet_id_and_user_id", unique: true
    t.index ["google_meet_id"], name: "index_meeting_participants_on_google_meet_id"
    t.index ["role"], name: "index_meeting_participants_on_role"
    t.index ["user_id"], name: "index_meeting_participants_on_user_id"
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

  create_table "ndas", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "project_name"
    t.text "project_description"
    t.date "effective_date"
    t.text "signature"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_ndas_on_customer_id"
    t.index ["user_id"], name: "index_ndas_on_user_id"
  end

  create_table "notification_logs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "customer_id", null: false
    t.string "notification_type", null: false
    t.datetime "sent_at", null: false
    t.text "message_preview"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_notification_logs_on_customer_id"
    t.index ["user_id", "customer_id", "notification_type", "sent_at"], name: "idx_notification_logs_lookup"
    t.index ["user_id"], name: "index_notification_logs_on_user_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "content"
    t.boolean "read", default: false
    t.string "notification_type"
    t.string "resource_type"
    t.bigint "resource_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_notifications_on_created_at"
    t.index ["resource_type", "resource_id"], name: "index_notifications_on_resource"
    t.index ["user_id", "read"], name: "index_notifications_on_user_id_and_read"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "pipelines", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active"], name: "index_pipelines_on_active"
    t.index ["name"], name: "index_pipelines_on_name", unique: true
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
    t.boolean "called_at_prefered_time", default: false, null: false
    t.index ["called_at_prefered_time"], name: "index_recordings_on_called_at_prefered_time"
    t.index ["customer_id"], name: "index_recordings_on_customer_id"
    t.index ["user_id"], name: "index_recordings_on_user_id"
  end

  create_table "role_assignments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "role_id", null: false
    t.bigint "assigned_by_id"
    t.string "resource_type"
    t.bigint "resource_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assigned_by_id"], name: "index_role_assignments_on_assigned_by_id"
    t.index ["resource_type", "resource_id"], name: "index_role_assignments_on_resource"
    t.index ["role_id"], name: "index_role_assignments_on_role_id"
    t.index ["user_id", "role_id", "resource_type", "resource_id"], name: "index_role_assignments_on_user_role_and_resource", unique: true
    t.index ["user_id"], name: "index_role_assignments_on_user_id"
  end

  create_table "roles", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "key", null: false
    t.integer "hierarchy_level", default: 0
    t.index ["hierarchy_level"], name: "index_roles_on_hierarchy_level"
    t.index ["key"], name: "index_roles_on_key", unique: true
  end

  create_table "sms", force: :cascade do |t|
    t.string "from_number"
    t.string "to_number"
    t.text "body"
    t.string "direction"
    t.string "status"
    t.string "message_sid"
    t.bigint "customer_id"
    t.bigint "user_id"
    t.string "message_type"
    t.string "media_url"
    t.integer "num_media", default: 0
    t.jsonb "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_sms_on_created_at"
    t.index ["customer_id"], name: "index_sms_on_customer_id"
    t.index ["direction"], name: "index_sms_on_direction"
    t.index ["from_number"], name: "index_sms_on_from_number"
    t.index ["message_sid"], name: "index_sms_on_message_sid", unique: true
    t.index ["status"], name: "index_sms_on_status"
    t.index ["to_number"], name: "index_sms_on_to_number"
    t.index ["user_id"], name: "index_sms_on_user_id"
  end

  create_table "system_settings", force: :cascade do |t|
    t.string "key", null: false
    t.text "value"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_system_settings_on_key", unique: true
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

  create_table "user_pipeline_assignments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "pipeline_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pipeline_id"], name: "index_user_pipeline_assignments_on_pipeline_id"
    t.index ["user_id", "pipeline_id"], name: "index_user_pipeline_assignments_on_user_id_and_pipeline_id", unique: true
    t.index ["user_id"], name: "index_user_pipeline_assignments_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "provider"
    t.string "uid"
    t.string "name"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "fcm_token"
    t.string "voip_device_id"
    t.string "device_platform"
    t.string "phone_number"
    t.string "google_token"
    t.string "google_refresh_token"
    t.datetime "google_token_expires_at"
    t.index ["fcm_token"], name: "index_users_on_fcm_token"
    t.index ["voip_device_id"], name: "index_users_on_voip_device_id"
  end

  create_table "whatsapp_messages", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "message_id", null: false
    t.string "remote_id"
    t.text "body"
    t.datetime "timestamp"
    t.string "direction"
    t.string "status"
    t.jsonb "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id", "timestamp"], name: "index_whatsapp_messages_on_customer_id_and_timestamp"
    t.index ["customer_id"], name: "index_whatsapp_messages_on_customer_id"
    t.index ["message_id"], name: "index_whatsapp_messages_on_message_id", unique: true
    t.index ["timestamp"], name: "index_whatsapp_messages_on_timestamp"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "ai_analyses", "recordings"
  add_foreign_key "ai_conversations", "customers"
  add_foreign_key "ai_conversations", "users"
  add_foreign_key "calls", "customers"
  add_foreign_key "calls", "users", column: "caller_id"
  add_foreign_key "calls", "users", column: "receiver_id"
  add_foreign_key "cost_estimates", "users"
  add_foreign_key "customer_activities", "customers"
  add_foreign_key "customer_activities", "users"
  add_foreign_key "customer_locations", "customers"
  add_foreign_key "customers", "users"
  add_foreign_key "deal_activities", "deals"
  add_foreign_key "deal_activities", "users"
  add_foreign_key "deal_recordings", "deal_stages"
  add_foreign_key "deal_recordings", "deals"
  add_foreign_key "deal_recordings", "users"
  add_foreign_key "deal_stages", "pipelines"
  add_foreign_key "deals", "customers"
  add_foreign_key "deals", "deal_stages"
  add_foreign_key "deals", "users"
  add_foreign_key "eleven_labs_calls", "customers"
  add_foreign_key "eleven_labs_calls", "users"
  add_foreign_key "email_attachments", "emails"
  add_foreign_key "emails", "customers"
  add_foreign_key "emails", "users"
  add_foreign_key "google_meets", "users"
  add_foreign_key "meeting_participants", "google_meets"
  add_foreign_key "meeting_participants", "users"
  add_foreign_key "messages", "customers"
  add_foreign_key "messages", "users"
  add_foreign_key "ndas", "customers"
  add_foreign_key "ndas", "users"
  add_foreign_key "notification_logs", "customers"
  add_foreign_key "notification_logs", "users"
  add_foreign_key "notifications", "users"
  add_foreign_key "recordings", "customers"
  add_foreign_key "recordings", "users"
  add_foreign_key "role_assignments", "roles"
  add_foreign_key "role_assignments", "users"
  add_foreign_key "role_assignments", "users", column: "assigned_by_id"
  add_foreign_key "sms", "customers"
  add_foreign_key "sms", "users"
  add_foreign_key "tasks", "customers"
  add_foreign_key "tasks", "users"
  add_foreign_key "user_pipeline_assignments", "pipelines"
  add_foreign_key "user_pipeline_assignments", "users"
  add_foreign_key "whatsapp_messages", "customers"
end
