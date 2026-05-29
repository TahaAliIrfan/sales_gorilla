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

ActiveRecord::Schema[7.1].define(version: 2026_05_30_033331) do
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

  create_table "calls", force: :cascade do |t|
    t.bigint "caller_id", null: false
    t.bigint "receiver_id"
    t.bigint "customer_id"
    t.integer "status", default: 0
    t.integer "call_type", default: 0
    t.datetime "started_at"
    t.datetime "ended_at"
    t.string "twilio_call_sid"
    t.string "webrtc_session_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "phone_number"
    t.index ["call_type"], name: "index_calls_on_call_type"
    t.index ["caller_id", "status"], name: "index_calls_on_caller_id_and_status"
    t.index ["caller_id"], name: "index_calls_on_caller_id"
    t.index ["customer_id"], name: "index_calls_on_customer_id"
    t.index ["receiver_id", "status"], name: "index_calls_on_receiver_id_and_status"
    t.index ["receiver_id"], name: "index_calls_on_receiver_id"
    t.index ["status"], name: "index_calls_on_status"
    t.index ["twilio_call_sid"], name: "index_calls_on_twilio_call_sid"
  end

  create_table "campaign_executions", force: :cascade do |t|
    t.bigint "campaign_id", null: false
    t.bigint "customer_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "scheduled_at", null: false
    t.datetime "executed_at"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id", "customer_id"], name: "index_campaign_executions_unique", unique: true
    t.index ["campaign_id"], name: "index_campaign_executions_on_campaign_id"
    t.index ["customer_id"], name: "index_campaign_executions_on_customer_id"
    t.index ["scheduled_at"], name: "index_campaign_executions_on_scheduled_at"
    t.index ["status"], name: "index_campaign_executions_on_status"
  end

  create_table "campaign_groups", force: :cascade do |t|
    t.bigint "campaign_id", null: false
    t.bigint "customer_group_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["campaign_id"], name: "index_campaign_groups_on_campaign_id"
    t.index ["customer_group_id"], name: "index_campaign_groups_on_customer_group_id"
  end

  create_table "campaigns", force: :cascade do |t|
    t.string "name", null: false
    t.text "message", null: false
    t.string "status", default: "draft", null: false
    t.datetime "scheduled_at"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["scheduled_at"], name: "index_campaigns_on_scheduled_at"
    t.index ["status"], name: "index_campaigns_on_status"
    t.index ["user_id"], name: "index_campaigns_on_user_id"
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
    t.boolean "include_design", default: false, null: false
    t.integer "customer_id"
    t.string "customer_name"
    t.string "project_name"
    t.text "project_overview"
    t.text "technical_information_summary"
    t.integer "estimated_timeline_weeks"
    t.string "team_composition"
    t.string "development_methodology"
    t.string "key_technology_areas"
    t.text "application_types"
    t.string "status", default: "init"
    t.text "proposed_features"
    t.string "app_name"
    t.text "similar_apps"
    t.text "mockups_html"
    t.string "pdf_url"
    t.text "executive_summary"
    t.text "feature_prioritization"
    t.index ["customer_id"], name: "index_cost_estimates_on_customer_id"
    t.index ["status"], name: "index_cost_estimates_on_status"
    t.index ["user_id"], name: "index_cost_estimates_on_user_id"
  end

  create_table "csv_uploads", force: :cascade do |t|
    t.string "upload_token"
    t.bigint "user_id", null: false
    t.string "original_filename"
    t.string "file_path"
    t.text "headers"
    t.text "sample_rows"
    t.text "suggested_mappings"
    t.integer "total_rows"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "lead_source"
    t.index ["upload_token"], name: "index_csv_uploads_on_upload_token", unique: true
    t.index ["user_id"], name: "index_csv_uploads_on_user_id"
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

  create_table "customer_group_memberships", force: :cascade do |t|
    t.bigint "customer_group_id", null: false
    t.bigint "customer_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_group_id", "customer_id"], name: "index_customer_group_memberships_unique", unique: true
    t.index ["customer_group_id"], name: "index_customer_group_memberships_on_customer_group_id"
    t.index ["customer_id"], name: "index_customer_group_memberships_on_customer_id"
  end

  create_table "customer_groups", force: :cascade do |t|
    t.string "name", null: false
    t.text "description"
    t.bigint "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "name"], name: "index_customer_groups_on_user_id_and_name"
    t.index ["user_id"], name: "index_customer_groups_on_user_id"
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
    t.string "state"
    t.string "city"
    t.string "area_code"
    t.string "geo_name"
    t.decimal "latitude", precision: 10, scale: 6
    t.decimal "longitude", precision: 10, scale: 6
    t.string "carrier"
    t.string "phone_type"
    t.decimal "timezone_offset", precision: 4, scale: 2
    t.string "timezone_abbreviation"
    t.datetime "phone_analysis_completed_at"
    t.string "phone_analysis_version", default: "1.0"
    t.boolean "repeat_lead", default: false, null: false
    t.integer "total_call_attempts", default: 0, null: false
    t.integer "successful_call_attempts", default: 0, null: false
    t.datetime "last_call_attempt_at"
    t.datetime "last_successful_call_at"
    t.string "utm_campaign"
    t.string "utm_term"
    t.string "gclid", limit: 512
    t.string "gbraid", limit: 512
    t.string "wbraid", limit: 512
    t.string "fbclid", limit: 512
    t.string "msclkid", limit: 512
    t.string "utm_source", limit: 255
    t.string "utm_medium", limit: 255
    t.string "utm_content", limit: 255
    t.text "landing_page"
    t.string "traffic_source", limit: 255
    t.string "lead_quality"
    t.datetime "lead_quality_marked_at"
    t.bigint "lead_quality_marked_by_id"
    t.datetime "google_conversion_sent_at"
    t.string "google_conversion_status"
    t.index ["area_code"], name: "index_customers_on_area_code"
    t.index ["browser_id"], name: "index_customers_on_browser_id"
    t.index ["carrier"], name: "index_customers_on_carrier"
    t.index ["city"], name: "index_customers_on_city"
    t.index ["facebook_click_id"], name: "index_customers_on_facebook_click_id"
    t.index ["gclid"], name: "index_customers_on_gclid"
    t.index ["google_conversion_status"], name: "index_customers_on_google_conversion_status"
    t.index ["latitude", "longitude"], name: "index_customers_on_coordinates"
    t.index ["lead_quality"], name: "index_customers_on_lead_quality"
    t.index ["meta_lead_id"], name: "index_customers_on_meta_lead_id"
    t.index ["phone_analysis_completed_at"], name: "index_customers_on_phone_analysis_completed_at"
    t.index ["state"], name: "index_customers_on_state"
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

  create_table "invoice_line_items", force: :cascade do |t|
    t.bigint "invoice_id", null: false
    t.bigint "milestone_item_id"
    t.string "description", null: false
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_invoice_line_items_on_invoice_id"
    t.index ["milestone_item_id"], name: "index_invoice_line_items_on_milestone_item_id"
    t.index ["position"], name: "index_invoice_line_items_on_position"
  end

  create_table "invoices", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "milestone_id", null: false
    t.bigint "user_id", null: false
    t.string "invoice_number", null: false
    t.string "project_name"
    t.text "description"
    t.date "issue_date", null: false
    t.date "due_date", null: false
    t.decimal "tax_rate", precision: 5, scale: 2, default: "0.0"
    t.decimal "tax_amount", precision: 12, scale: 2, default: "0.0"
    t.decimal "total", precision: 12, scale: 2, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "payment_link"
    t.string "status", default: "pending", null: false
    t.string "public_token"
    t.string "payment_link_label"
    t.index ["customer_id"], name: "index_invoices_on_customer_id"
    t.index ["invoice_number"], name: "index_invoices_on_invoice_number", unique: true
    t.index ["issue_date"], name: "index_invoices_on_issue_date"
    t.index ["milestone_id"], name: "index_invoices_on_milestone_id"
    t.index ["public_token"], name: "index_invoices_on_public_token", unique: true
    t.index ["status"], name: "index_invoices_on_status"
    t.index ["user_id"], name: "index_invoices_on_user_id"
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

  create_table "meta_conversion_logs", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "event_name", null: false
    t.boolean "success", default: false, null: false
    t.string "response_code"
    t.jsonb "response_body"
    t.string "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "request_payload"
    t.index ["customer_id", "created_at"], name: "index_meta_conversion_logs_on_customer_id_and_created_at"
    t.index ["customer_id"], name: "index_meta_conversion_logs_on_customer_id"
  end

  create_table "milestone_items", force: :cascade do |t|
    t.bigint "milestone_id", null: false
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.date "due_date"
    t.string "description", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["milestone_id"], name: "index_milestone_items_on_milestone_id"
    t.index ["position"], name: "index_milestone_items_on_position"
  end

  create_table "milestones", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.decimal "total_amount", precision: 12, scale: 2, null: false
    t.string "schedule_type", default: "milestone", null: false
    t.string "status", default: "unpaid", null: false
    t.datetime "paid_at"
    t.string "currency", default: "USD"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_milestones_on_customer_id"
    t.index ["schedule_type"], name: "index_milestones_on_schedule_type"
    t.index ["status"], name: "index_milestones_on_status"
    t.index ["user_id"], name: "index_milestones_on_user_id"
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

  create_table "odoo_proposals", force: :cascade do |t|
    t.bigint "customer_id"
    t.bigint "user_id", null: false
    t.string "customer_name"
    t.string "deployment_type", default: "online", null: false
    t.string "hosting_tier"
    t.integer "num_users", default: 5, null: false
    t.jsonb "selected_modules", default: [], null: false
    t.decimal "implementation_fee", precision: 12, scale: 2, default: "0.0"
    t.decimal "annual_hosting_cost", precision: 12, scale: 2, default: "0.0"
    t.text "notes"
    t.string "status", default: "draft"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "industry"
    t.string "company_size"
    t.jsonb "pain_points", default: []
    t.text "claude_summary"
    t.text "claude_rationale"
    t.jsonb "claude_module_justifications", default: {}
    t.text "claude_next_steps"
    t.datetime "narrative_generated_at"
    t.jsonb "custom_modules", default: []
    t.index ["customer_id"], name: "index_odoo_proposals_on_customer_id"
    t.index ["user_id"], name: "index_odoo_proposals_on_user_id"
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

  create_table "user_kpi_records", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.date "record_date", null: false
    t.integer "calls_attempted", default: 0, null: false
    t.integer "connected_calls", default: 0, null: false
    t.integer "whatsapp_messages_sent", default: 0, null: false
    t.integer "emails_sent", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_date"], name: "index_user_kpi_records_on_record_date"
    t.index ["user_id", "record_date"], name: "index_user_kpi_records_on_user_id_and_record_date", unique: true
    t.index ["user_id"], name: "index_user_kpi_records_on_user_id"
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
    t.boolean "active", default: true, null: false
    t.index ["active"], name: "index_users_on_active"
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

  create_table "whatsapp_templates", force: :cascade do |t|
    t.string "content_sid", null: false
    t.string "friendly_name"
    t.string "language"
    t.string "category"
    t.string "approval_status"
    t.text "body"
    t.jsonb "types", default: {}
    t.jsonb "variables", default: {}
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approval_status"], name: "index_whatsapp_templates_on_approval_status"
    t.index ["content_sid"], name: "index_whatsapp_templates_on_content_sid", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "calls", "customers"
  add_foreign_key "calls", "users", column: "caller_id"
  add_foreign_key "calls", "users", column: "receiver_id"
  add_foreign_key "campaign_executions", "campaigns"
  add_foreign_key "campaign_executions", "customers"
  add_foreign_key "campaign_groups", "campaigns"
  add_foreign_key "campaign_groups", "customer_groups"
  add_foreign_key "campaigns", "users"
  add_foreign_key "cost_estimates", "customers", on_delete: :nullify
  add_foreign_key "cost_estimates", "users"
  add_foreign_key "csv_uploads", "users"
  add_foreign_key "customer_activities", "customers"
  add_foreign_key "customer_activities", "users"
  add_foreign_key "customer_group_memberships", "customer_groups"
  add_foreign_key "customer_group_memberships", "customers"
  add_foreign_key "customer_groups", "users"
  add_foreign_key "customer_locations", "customers"
  add_foreign_key "customers", "users"
  add_foreign_key "customers", "users", column: "lead_quality_marked_by_id"
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
  add_foreign_key "emails", "customers"
  add_foreign_key "emails", "users"
  add_foreign_key "google_meets", "users"
  add_foreign_key "invoice_line_items", "invoices"
  add_foreign_key "invoice_line_items", "milestone_items"
  add_foreign_key "invoices", "customers"
  add_foreign_key "invoices", "milestones"
  add_foreign_key "invoices", "users"
  add_foreign_key "meeting_participants", "google_meets"
  add_foreign_key "meeting_participants", "users"
  add_foreign_key "messages", "customers"
  add_foreign_key "messages", "users"
  add_foreign_key "meta_conversion_logs", "customers"
  add_foreign_key "milestone_items", "milestones"
  add_foreign_key "milestones", "customers"
  add_foreign_key "milestones", "users"
  add_foreign_key "ndas", "customers"
  add_foreign_key "ndas", "users"
  add_foreign_key "notification_logs", "customers"
  add_foreign_key "notification_logs", "users"
  add_foreign_key "notifications", "users"
  add_foreign_key "odoo_proposals", "customers"
  add_foreign_key "odoo_proposals", "users"
  add_foreign_key "recordings", "customers"
  add_foreign_key "recordings", "users"
  add_foreign_key "role_assignments", "roles"
  add_foreign_key "role_assignments", "users"
  add_foreign_key "role_assignments", "users", column: "assigned_by_id"
  add_foreign_key "sms", "customers"
  add_foreign_key "sms", "users"
  add_foreign_key "tasks", "customers"
  add_foreign_key "tasks", "users"
  add_foreign_key "user_kpi_records", "users"
  add_foreign_key "user_pipeline_assignments", "pipelines"
  add_foreign_key "user_pipeline_assignments", "users"
  add_foreign_key "whatsapp_messages", "customers"
end
