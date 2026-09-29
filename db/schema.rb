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

ActiveRecord::Schema[8.1].define(version: 2026_09_29_080712) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "unaccent"

  create_table "accounts", force: :cascade do |t|
    t.string "base_currency", limit: 3, default: "EUR", null: false
    t.datetime "base_currency_changed_at"
    t.string "country", limit: 2, null: false
    t.datetime "created_at", null: false
    t.string "csv_separator", default: "comma", null: false
    t.string "default_locale"
    t.string "item_identification", default: "fifo", null: false
    t.bigint "label_threshold_cents"
    t.string "name", null: false
    t.string "rebase_status", default: "idle", null: false
    t.string "time_zone", default: "UTC", null: false
    t.string "trade_valuation_method", default: "carryover", null: false
    t.datetime "updated_at", null: false
    t.string "vat_mode", default: "gross", null: false
  end

  create_table "cardtrader_blueprints", force: :cascade do |t|
    t.string "cardmarket_id"
    t.integer "cardtrader_id", null: false
    t.integer "category_id"
    t.datetime "created_at", null: false
    t.string "expansion_name"
    t.integer "game_id"
    t.string "image_url"
    t.string "name", null: false
    t.string "scryfall_id"
    t.datetime "updated_at", null: false
    t.index ["cardtrader_id"], name: "index_cardtrader_blueprints_on_cardtrader_id", unique: true
    t.index ["name"], name: "index_cardtrader_blueprints_on_name"
  end

  create_table "catalog_sync_runs", force: :cascade do |t|
    t.integer "blueprints_removed", default: 0, null: false
    t.integer "blueprints_upserted", default: 0, null: false
    t.datetime "created_at", null: false
    t.integer "expansions_done", default: 0, null: false
    t.integer "expansions_total", default: 0, null: false
    t.datetime "finished_at"
    t.datetime "started_at"
    t.string "status", default: "pending", null: false
    t.jsonb "sync_errors", default: [], null: false
    t.string "trigger", null: false
    t.bigint "triggered_by_id"
    t.datetime "updated_at", null: false
    t.index ["triggered_by_id"], name: "index_catalog_sync_runs_on_triggered_by_id"
  end

  create_table "ct_blueprints", force: :cascade do |t|
    t.integer "card_market_ids", default: [], null: false, array: true
    t.string "collector_number"
    t.datetime "created_at", null: false
    t.integer "ct_category_id", null: false
    t.integer "ct_expansion_id"
    t.integer "ct_game_id", null: false
    t.integer "ct_id", null: false
    t.jsonb "editable_properties", default: {}, null: false
    t.jsonb "fixed_properties", default: {}, null: false
    t.string "image_url"
    t.string "name", null: false
    t.string "rarity"
    t.datetime "removed_at"
    t.string "scryfall_id"
    t.text "search_text"
    t.datetime "synced_at"
    t.string "tcg_player_id"
    t.datetime "updated_at", null: false
    t.string "version"
    t.index ["card_market_ids"], name: "index_ct_blueprints_on_card_market_ids", using: :gin
    t.index ["collector_number"], name: "index_ct_blueprints_on_collector_number"
    t.index ["ct_expansion_id", "ct_category_id"], name: "index_ct_blueprints_on_ct_expansion_id_and_ct_category_id"
    t.index ["ct_id"], name: "index_ct_blueprints_on_ct_id", unique: true
    t.index ["scryfall_id"], name: "index_ct_blueprints_on_scryfall_id"
    t.index ["search_text"], name: "index_ct_blueprints_on_search_text_trgm", opclass: :gin_trgm_ops, using: :gin
    t.index ["tcg_player_id"], name: "index_ct_blueprints_on_tcg_player_id"
  end

  create_table "ct_categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "ct_game_id", null: false
    t.integer "ct_id", null: false
    t.string "name", null: false
    t.jsonb "properties", default: {}, null: false
    t.datetime "synced_at"
    t.datetime "updated_at", null: false
    t.index ["ct_game_id"], name: "index_ct_categories_on_ct_game_id"
    t.index ["ct_id"], name: "index_ct_categories_on_ct_id", unique: true
  end

  create_table "ct_expansions", force: :cascade do |t|
    t.string "code"
    t.datetime "created_at", null: false
    t.integer "ct_game_id", null: false
    t.integer "ct_id", null: false
    t.string "export_status", default: "ok", null: false
    t.string "name", null: false
    t.datetime "removed_at"
    t.datetime "synced_at"
    t.datetime "updated_at", null: false
    t.index ["ct_game_id"], name: "index_ct_expansions_on_ct_game_id"
    t.index ["ct_id"], name: "index_ct_expansions_on_ct_id", unique: true
  end

  create_table "ct_games", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "ct_id", null: false
    t.string "display_name"
    t.boolean "enabled", default: true, null: false
    t.string "name", null: false
    t.datetime "synced_at"
    t.datetime "updated_at", null: false
    t.index ["ct_id"], name: "index_ct_games_on_ct_id", unique: true
  end

  create_table "inventory_items", force: :cascade do |t|
    t.integer "allocated_cost_cents"
    t.string "card_name", null: false
    t.string "cardmarket_id"
    t.integer "cardtrader_blueprint_id"
    t.integer "cardtrader_expansion_id"
    t.integer "cardtrader_product_id"
    t.integer "category_id"
    t.string "condition"
    t.datetime "created_at", null: false
    t.integer "game_id"
    t.string "image_url"
    t.boolean "is_foil", default: false, null: false
    t.boolean "is_sealed_product", default: false, null: false
    t.string "language"
    t.integer "purchase_id"
    t.string "scryfall_id"
    t.string "set_name"
    t.string "status", default: "in_stock", null: false
    t.datetime "updated_at", null: false
    t.index ["cardtrader_blueprint_id"], name: "index_inventory_items_on_cardtrader_blueprint_id"
    t.index ["cardtrader_product_id"], name: "index_inventory_items_on_cardtrader_product_id"
    t.index ["purchase_id"], name: "index_inventory_items_on_purchase_id"
  end

  create_table "invitations", force: :cascade do |t|
    t.datetime "accepted_at"
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.citext "email", null: false
    t.datetime "expires_at", null: false
    t.bigint "invited_by_id"
    t.string "role", null: false
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_invitations_on_account_id"
    t.index ["invited_by_id"], name: "index_invitations_on_invited_by_id"
    t.index ["token_digest"], name: "index_invitations_on_token_digest", unique: true
  end

  create_table "memberships", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.datetime "created_at", null: false
    t.string "role", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["account_id", "user_id"], name: "index_memberships_on_account_id_and_user_id", unique: true
    t.index ["account_id"], name: "index_memberships_on_account_id"
    t.index ["account_id"], name: "index_memberships_on_account_id_when_owner", unique: true, where: "((role)::text = 'owner'::text)"
    t.index ["user_id"], name: "index_memberships_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "solid_cable_messages", force: :cascade do |t|
    t.binary "channel", null: false
    t.bigint "channel_hash", null: false
    t.datetime "created_at", null: false
    t.binary "payload", null: false
    t.index ["channel"], name: "index_solid_cable_messages_on_channel"
    t.index ["channel_hash"], name: "index_solid_cable_messages_on_channel_hash"
    t.index ["created_at"], name: "index_solid_cable_messages_on_created_at"
  end

  create_table "solid_cache_entries", force: :cascade do |t|
    t.integer "byte_size", null: false
    t.datetime "created_at", null: false
    t.binary "key", null: false
    t.bigint "key_hash", null: false
    t.binary "value", null: false
    t.index ["byte_size"], name: "index_solid_cache_entries_on_byte_size"
    t.index ["key_hash", "byte_size"], name: "index_solid_cache_entries_on_key_hash_and_byte_size"
    t.index ["key_hash"], name: "index_solid_cache_entries_on_key_hash", unique: true
  end

  create_table "solid_queue_batch_executions", force: :cascade do |t|
    t.bigint "batch_id", null: false
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.index ["batch_id"], name: "index_solid_queue_batch_executions_on_batch_id"
    t.index ["job_id"], name: "index_solid_queue_batch_executions_on_job_id", unique: true
  end

  create_table "solid_queue_batches", force: :cascade do |t|
    t.string "active_job_batch_id"
    t.integer "completed_jobs", default: 0, null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.datetime "enqueued_at"
    t.datetime "failed_at"
    t.integer "failed_jobs", default: 0, null: false
    t.datetime "finished_at"
    t.text "metadata"
    t.text "on_failure"
    t.text "on_finish"
    t.text "on_success"
    t.integer "total_jobs", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["active_job_batch_id"], name: "index_solid_queue_batches_on_active_job_batch_id", unique: true
    t.index ["finished_at"], name: "index_solid_queue_batches_on_finished_at"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.bigint "batch_id"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["batch_id"], name: "index_solid_queue_jobs_on_batch_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.citext "email", null: false
    t.string "locale"
    t.string "name"
    t.string "otp_secret"
    t.string "password_digest", null: false
    t.boolean "super_admin", default: false, null: false
    t.string "time_zone", default: "UTC", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.bigint "item_id", null: false
    t.string "item_type", null: false
    t.text "object"
    t.string "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
  end

  add_foreign_key "catalog_sync_runs", "users", column: "triggered_by_id"
  add_foreign_key "invitations", "accounts"
  add_foreign_key "invitations", "users", column: "invited_by_id"
  add_foreign_key "memberships", "accounts"
  add_foreign_key "memberships", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "solid_queue_batch_executions", "solid_queue_batches", column: "batch_id", on_delete: :cascade
  add_foreign_key "solid_queue_batch_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
end
