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

ActiveRecord::Schema[8.1].define(version: 2026_09_21_143319) do
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

  create_table "purchases", force: :cascade do |t|
    t.integer "cardtrader_order_id"
    t.datetime "created_at", null: false
    t.string "currency", default: "EUR", null: false
    t.string "name", null: false
    t.text "notes"
    t.string "product_type"
    t.date "purchase_date"
    t.integer "shipping_cost_cents"
    t.string "source"
    t.integer "tax_cents"
    t.integer "total_price_cents"
    t.datetime "updated_at", null: false
    t.boolean "via_cardtrader_zero", default: false, null: false
    t.index ["cardtrader_order_id"], name: "index_purchases_on_cardtrader_order_id"
  end

  create_table "sales", force: :cascade do |t|
    t.integer "cardtrader_order_id"
    t.datetime "created_at", null: false
    t.integer "inventory_item_id", null: false
    t.integer "net_profit_cents"
    t.string "platform"
    t.integer "platform_fees_cents"
    t.date "sale_date"
    t.integer "sale_price_cents"
    t.integer "shipping_cost_cents"
    t.datetime "updated_at", null: false
    t.index ["cardtrader_order_id"], name: "index_sales_on_cardtrader_order_id"
    t.index ["inventory_item_id"], name: "index_sales_on_inventory_item_id"
  end

  add_foreign_key "inventory_items", "purchases"
  add_foreign_key "sales", "inventory_items"
end
