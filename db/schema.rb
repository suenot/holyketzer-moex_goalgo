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

ActiveRecord::Schema[7.1].define(version: 2023_12_03_164400) do
  create_schema "_timescaledb_cache"
  create_schema "_timescaledb_catalog"
  create_schema "_timescaledb_config"
  create_schema "_timescaledb_functions"
  create_schema "_timescaledb_internal"
  create_schema "timescaledb_experimental"
  create_schema "timescaledb_information"

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "timescaledb"

  create_table "share_macro_stats", force: :cascade do |t|
    t.bigint "share_id", null: false
    t.string "secid", null: false
    t.string "date", null: false
    t.bigint "shares_count", null: false
    t.money "cap", scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["secid", "date"], name: "index_share_macro_stats_on_secid_and_date", unique: true
    t.index ["share_id"], name: "index_share_macro_stats_on_share_id"
  end

  create_table "share_prices", force: :cascade do |t|
    t.bigint "share_id", null: false
    t.string "secid", null: false
    t.date "date", null: false
    t.decimal "open", precision: 10, scale: 2
    t.decimal "close", precision: 10, scale: 2
    t.decimal "low", precision: 10, scale: 2
    t.decimal "high", precision: 10, scale: 2
    t.bigint "volume"
    t.decimal "waprice", precision: 10, scale: 2
    t.index ["secid"], name: "index_share_prices_on_secid"
    t.index ["share_id", "date"], name: "index_share_prices_on_share_id_and_date", unique: true
    t.index ["share_id"], name: "index_share_prices_on_share_id"
  end

  create_table "shares", force: :cascade do |t|
    t.string "secid", null: false
    t.string "name", null: false
    t.string "short_name", null: false
    t.string "isin", null: false
    t.bigint "issue_size", null: false
    t.integer "nominal_price_amount", default: 0, null: false
    t.string "nominal_price_currency", default: "RUB", null: false
    t.date "issue_date"
    t.integer "list_level"
    t.string "sec_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "history_from"
    t.integer "emmiter_id"
    t.money "cap", scale: 2
    t.integer "version", default: 0, null: false
    t.index ["isin"], name: "index_shares_on_isin"
    t.index ["secid"], name: "index_shares_on_secid", unique: true
  end

end
