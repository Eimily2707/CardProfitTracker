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

ActiveRecord::Schema[8.1].define(version: 2026_09_29_100004) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "unaccent"

  create_table "accounts", force: :cascade do |t|
    t.string "name", null: false
    t.string "base_currency", limit: 3, default: "EUR", null: false
    t.datetime "base_currency_changed_at"
    t.string "rebase_status", default: "idle", null: false
    t.string "time_zone", default: "UTC", null: false
    t.string "default_locale"
    t.string "item_identification", default: "fifo", null: false
    t.bigint "label_threshold_cents"
    t.string "csv_separator", default: "comma", null: false
    t.string "country", limit: 2, null: false
    t.string "vat_mode", default: "gross", null: false
    t.string "trade_valuation_method", default: "carryover", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "cardtrader_order_sync_runs", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "triggered_by_id"
    t.string "status", default: "queued", null: false
    t.string "trigger", null: false
    t.datetime "started_at"
    t.datetime "finished_at"
    t.integer "orders_created", default: 0, null: false
    t.integer "orders_updated", default: 0, null: false
    t.integer "orders_failed", default: 0, null: false
    t.jsonb "sync_errors", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_cardtrader_order_sync_runs_on_account_id"
    t.index ["triggered_by_id"], name: "index_cardtrader_order_sync_runs_on_triggered_by_id"
  end

  create_table "catalog_sync_runs", force: :cascade do |t|
    t.string "status", default: "pending", null: false
    t.string "trigger", null: false
    t.datetime "started_at"
    t.datetime "finished_at"
    t.integer "expansions_total", default: 0, null: false
    t.integer "expansions_done", default: 0, null: false
    t.integer "blueprints_upserted", default: 0, null: false
    t.integer "blueprints_removed", default: 0, null: false
    t.jsonb "sync_errors", default: [], null: false
    t.bigint "triggered_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["triggered_by_id"], name: "index_catalog_sync_runs_on_triggered_by_id"
  end

  create_table "channels", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.string "name", null: false
    t.string "kind", null: false
    t.string "system_key"
    t.string "usage", default: "both", null: false
    t.string "credit_timing", default: "manual", null: false
    t.string "default_currency", limit: 3
    t.boolean "allows_bundles", default: true, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "name"], name: "index_channels_on_account_id_and_name", unique: true
    t.index ["account_id", "system_key"], name: "index_channels_on_account_id_and_system_key", unique: true
    t.index ["account_id"], name: "index_channels_on_account_id"
  end

  create_table "ct_blueprints", force: :cascade do |t|
    t.integer "ct_id", null: false
    t.string "name", null: false
    t.string "version"
    t.integer "ct_game_id", null: false
    t.integer "ct_category_id", null: false
    t.integer "ct_expansion_id"
    t.string "image_url"
    t.jsonb "editable_properties", default: {}, null: false
    t.jsonb "fixed_properties", default: {}, null: false
    t.string "collector_number"
    t.string "rarity"
    t.string "scryfall_id"
    t.integer "card_market_ids", default: [], null: false, array: true
    t.string "tcg_player_id"
    t.text "search_text"
    t.datetime "synced_at"
    t.datetime "removed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["card_market_ids"], name: "index_ct_blueprints_on_card_market_ids", using: :gin
    t.index ["collector_number"], name: "index_ct_blueprints_on_collector_number"
    t.index ["ct_expansion_id", "ct_category_id"], name: "index_ct_blueprints_on_ct_expansion_id_and_ct_category_id"
    t.index ["ct_id"], name: "index_ct_blueprints_on_ct_id", unique: true
    t.index ["scryfall_id"], name: "index_ct_blueprints_on_scryfall_id"
    t.index ["search_text"], name: "index_ct_blueprints_on_search_text_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["tcg_player_id"], name: "index_ct_blueprints_on_tcg_player_id"
  end

  create_table "ct_categories", force: :cascade do |t|
    t.integer "ct_id", null: false
    t.integer "ct_game_id", null: false
    t.string "name", null: false
    t.jsonb "properties", default: {}, null: false
    t.datetime "synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ct_game_id"], name: "index_ct_categories_on_ct_game_id"
    t.index ["ct_id"], name: "index_ct_categories_on_ct_id", unique: true
  end

  create_table "ct_expansions", force: :cascade do |t|
    t.integer "ct_id", null: false
    t.integer "ct_game_id", null: false
    t.string "code"
    t.string "name", null: false
    t.string "export_status", default: "ok", null: false
    t.datetime "synced_at"
    t.datetime "removed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ct_game_id"], name: "index_ct_expansions_on_ct_game_id"
    t.index ["ct_id"], name: "index_ct_expansions_on_ct_id", unique: true
  end

  create_table "ct_games", force: :cascade do |t|
    t.integer "ct_id", null: false
    t.string "name", null: false
    t.string "display_name"
    t.boolean "enabled", default: true, null: false
    t.datetime "synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ct_id"], name: "index_ct_games_on_ct_id", unique: true
  end

  create_table "inventory_items", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "purchase_line_id"
    t.string "acquisition_type", default: "purchase", null: false
    t.string "public_ref", null: false
    t.bigint "ct_blueprint_id"
    t.bigint "ct_game_id"
    t.string "kind", null: false
    t.string "name", null: false
    t.string "expansion_name"
    t.jsonb "properties", default: {}, null: false
    t.integer "quantity", default: 1, null: false
    t.string "intent", null: false
    t.string "status", default: "pending_arrival", null: false
    t.bigint "acquisition_cost_base_cents", default: 0, null: false
    t.bigint "cost_base_cents", default: 0, null: false
    t.boolean "cost_estimated", default: false, null: false
    t.string "cost_source", null: false
    t.date "acquired_on", null: false
    t.string "location"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "public_ref"], name: "index_inventory_items_on_account_id_and_public_ref", unique: true
    t.index ["account_id", "status"], name: "index_inventory_items_on_account_id_and_status"
    t.index ["account_id"], name: "index_inventory_items_on_account_id"
    t.index ["ct_blueprint_id"], name: "index_inventory_items_on_ct_blueprint_id"
    t.index ["ct_game_id"], name: "index_inventory_items_on_ct_game_id"
    t.index ["purchase_line_id"], name: "index_inventory_items_on_purchase_line_id"
  end

  create_table "invitations", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.citext "email", null: false
    t.string "role", null: false
    t.string "token_digest", null: false
    t.datetime "expires_at", null: false
    t.datetime "accepted_at"
    t.bigint "invited_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_invitations_on_account_id"
    t.index ["invited_by_id"], name: "index_invitations_on_invited_by_id"
    t.index ["token_digest"], name: "index_invitations_on_token_digest", unique: true
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "user_id", null: false
    t.string "role", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "user_id"], name: "index_memberships_on_account_id_and_user_id", unique: true
    t.index ["account_id"], name: "index_memberships_on_account_id"
    t.index ["account_id"], name: "index_memberships_on_account_id_when_owner", unique: true, where: "((role)::text = 'owner'::text)"
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "purchase_charges", force: :cascade do |t|
    t.bigint "purchase_id", null: false
    t.string "kind", null: false
    t.bigint "amount_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["purchase_id"], name: "index_purchase_charges_on_purchase_id"
  end

  create_table "purchase_lines", force: :cascade do |t|
    t.bigint "purchase_id", null: false
    t.bigint "ct_blueprint_id"
    t.string "description", null: false
    t.string "expansion_name"
    t.string "kind", null: false
    t.string "intent", null: false
    t.integer "quantity", default: 1, null: false
    t.bigint "unit_price_cents", default: 0, null: false
    t.bigint "line_total_cents", default: 0, null: false
    t.jsonb "properties", default: {}, null: false
    t.string "status", default: "active", null: false
    t.bigint "landed_base_cents"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ct_blueprint_id"], name: "index_purchase_lines_on_ct_blueprint_id"
    t.index ["purchase_id"], name: "index_purchase_lines_on_purchase_id"
  end

  create_table "purchases", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "channel_id", null: false
    t.bigint "created_by_id"
    t.string "origin", default: "manual", null: false
    t.string "title", null: false
    t.string "seller_ref"
    t.datetime "ordered_at"
    t.datetime "received_at"
    t.string "currency", limit: 3, null: false
    t.bigint "subtotal_cents", default: 0, null: false
    t.bigint "charges_total_cents", default: 0, null: false
    t.bigint "refunds_total_cents", default: 0, null: false
    t.bigint "total_cents", default: 0, null: false
    t.decimal "fx_rate", precision: 20, scale: 10
    t.date "fx_rate_date"
    t.string "fx_source", default: "manual", null: false
    t.bigint "total_base_cents"
    t.string "status", default: "draft", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "status"], name: "index_purchases_on_account_id_and_status"
    t.index ["account_id"], name: "index_purchases_on_account_id"
    t.index ["channel_id"], name: "index_purchases_on_channel_id"
    t.index ["created_by_id"], name: "index_purchases_on_created_by_id"
  end

  create_table "sale_charges", force: :cascade do |t|
    t.bigint "sale_order_id", null: false
    t.string "kind", null: false
    t.string "direction", null: false
    t.bigint "amount_cents", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["sale_order_id"], name: "index_sale_charges_on_sale_order_id"
  end

  create_table "sale_lines", force: :cascade do |t|
    t.bigint "sale_order_id", null: false
    t.bigint "inventory_item_id"
    t.bigint "ct_blueprint_id"
    t.string "external_order_item_id"
    t.string "description", null: false
    t.integer "quantity", default: 1, null: false
    t.bigint "unit_price_cents", default: 0, null: false
    t.string "match_method"
    t.string "status", default: "active", null: false
    t.bigint "cost_base_cents_snapshot"
    t.bigint "allocated_net_charges_base_cents"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ct_blueprint_id"], name: "index_sale_lines_on_ct_blueprint_id"
    t.index ["inventory_item_id"], name: "index_sale_lines_on_inventory_item_id"
    t.index ["inventory_item_id"], name: "index_sale_lines_on_inventory_item_id_when_active", unique: true, where: "((status)::text = 'active'::text)"
    t.index ["sale_order_id"], name: "index_sale_lines_on_sale_order_id"
  end

  create_table "sale_orders", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.bigint "channel_id", null: false
    t.bigint "created_by_id"
    t.string "origin", default: "manual", null: false
    t.string "external_order_id"
    t.string "external_order_code"
    t.string "external_transaction_code"
    t.string "external_state"
    t.datetime "external_state_changed_at"
    t.boolean "via_cardtrader_zero", default: false, null: false
    t.boolean "presale", default: false, null: false
    t.string "buyer_ref"
    t.datetime "sold_at"
    t.datetime "credited_at"
    t.string "credit_source", default: "manual", null: false
    t.string "currency", limit: 3, null: false
    t.bigint "items_subtotal_cents", default: 0, null: false
    t.bigint "income_total_cents", default: 0, null: false
    t.bigint "expense_total_cents", default: 0, null: false
    t.bigint "net_proceeds_cents", default: 0, null: false
    t.decimal "fx_rate", precision: 20, scale: 10
    t.date "fx_rate_date"
    t.string "fx_source", default: "manual", null: false
    t.bigint "net_proceeds_base_cents"
    t.bigint "cogs_base_cents"
    t.bigint "profit_base_cents"
    t.string "status", default: "draft", null: false
    t.boolean "review_required", default: false, null: false
    t.string "review_reasons", default: [], null: false, array: true
    t.string "payment_method"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "channel_id", "external_order_id"], name: "idx_on_account_id_channel_id_external_order_id_55658c2e4f", unique: true
    t.index ["account_id", "status"], name: "index_sale_orders_on_account_id_and_status"
    t.index ["account_id"], name: "index_sale_orders_on_account_id"
    t.index ["channel_id"], name: "index_sale_orders_on_channel_id"
    t.index ["created_by_id"], name: "index_sale_orders_on_created_by_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.binary "payload", null: false
    t.datetime "created_at", null: false
    t.bigint "channel_hash", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.binary "key", null: false
    t.binary "value", null: false
    t.datetime "created_at", null: false
    t.bigint "key_hash", null: false
    t.integer "byte_size", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_batch_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.index ["batch_id"], name: "index_solid_queue_batch_executions_on_batch_id"
    t.index ["job_id"], name: "index_solid_queue_batch_executions_on_job_id", unique: true
  end

  create_table "solid_queue_batches", force: :cascade do |t|
    t.string "active_job_batch_id"
    t.string "description"
    t.text "on_finish"
    t.text "on_success"
    t.text "on_failure"
    t.text "metadata"
    t.integer "total_jobs", default: 0, null: false
    t.integer "completed_jobs", default: 0, null: false
    t.integer "failed_jobs", default: 0, null: false
    t.datetime "enqueued_at"
    t.datetime "finished_at"
    t.datetime "failed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_batch_id"], name: "index_solid_queue_batches_on_active_job_batch_id", unique: true
    t.index ["finished_at"], name: "index_solid_queue_batches_on_finished_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.string "concurrency_key", null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.text "error"
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "queue_name", null: false
    t.string "class_name", null: false
    t.text "arguments"
    t.integer "priority", default: 0, null: false
    t.string "active_job_id"
    t.datetime "scheduled_at"
    t.datetime "finished_at"
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "batch_id"
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["batch_id"], name: "index_solid_queue_jobs_on_batch_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.string "queue_name", null: false
    t.datetime "created_at", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.bigint "supervisor_id"
    t.integer "pid", null: false
    t.string "hostname"
    t.text "metadata"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "task_key", null: false
    t.datetime "run_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.string "key", null: false
    t.string "schedule", null: false
    t.string "command", limit: 2048
    t.string "class_name"
    t.text "arguments"
    t.string "queue_name"
    t.integer "priority", default: 0
    t.boolean "static", default: true, null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.string "queue_name", null: false
    t.integer "priority", default: 0, null: false
    t.datetime "scheduled_at", null: false
    t.datetime "created_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.string "key", null: false
    t.integer "value", default: 1, null: false
    t.datetime "expires_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "state_transitions", force: :cascade do |t|
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.string "from_state"
    t.string "to_state", null: false
    t.string "event", null: false
    t.string "source", default: "user", null: false
    t.bigint "actor_user_id"
    t.text "reason"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "occurred_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_user_id"], name: "index_state_transitions_on_actor_user_id"
    t.index ["record_type", "record_id", "occurred_at"], name: "idx_on_record_type_record_id_occurred_at_592847f3f1"
  end

  create_table "users", force: :cascade do |t|
    t.citext "email", null: false
    t.string "password_digest", null: false
    t.string "name"
    t.string "locale"
    t.string "time_zone", default: "UTC", null: false
    t.datetime "confirmed_at"
    t.string "otp_secret"
    t.boolean "super_admin", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.string "whodunnit"
    t.datetime "created_at"
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.string "event", null: false
    t.text "object"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "cardtrader_order_sync_runs", "accounts"
  add_foreign_key "cardtrader_order_sync_runs", "users", column: "triggered_by_id"
  add_foreign_key "catalog_sync_runs", "users", column: "triggered_by_id"
  add_foreign_key "channels", "accounts"
  add_foreign_key "inventory_items", "accounts"
  add_foreign_key "inventory_items", "ct_blueprints"
  add_foreign_key "inventory_items", "ct_games"
  add_foreign_key "inventory_items", "purchase_lines"
  add_foreign_key "invitations", "accounts"
  add_foreign_key "invitations", "users", column: "invited_by_id"
  add_foreign_key "memberships", "accounts"
  add_foreign_key "memberships", "users"
  add_foreign_key "purchase_charges", "purchases"
  add_foreign_key "purchase_lines", "ct_blueprints"
  add_foreign_key "purchase_lines", "purchases"
  add_foreign_key "purchases", "accounts"
  add_foreign_key "purchases", "channels"
  add_foreign_key "purchases", "users", column: "created_by_id"
  add_foreign_key "sale_charges", "sale_orders"
  add_foreign_key "sale_lines", "ct_blueprints"
  add_foreign_key "sale_lines", "inventory_items"
  add_foreign_key "sale_lines", "sale_orders"
  add_foreign_key "sale_orders", "accounts"
  add_foreign_key "sale_orders", "channels"
  add_foreign_key "sale_orders", "users", column: "created_by_id"
  add_foreign_key "sessions", "users"
  add_foreign_key "solid_queue_batch_executions", "solid_queue_batches", column: "batch_id", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "state_transitions", "users", column: "actor_user_id"
end
