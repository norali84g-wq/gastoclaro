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

ActiveRecord::Schema[8.1].define(version: 2026_09_30_025205) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "categories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "parent_id"
    t.boolean "tracks_installments"
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_categories_on_parent_id"
  end

  create_table "expense_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "expense_id", null: false
    t.string "name", null: false
    t.integer "quantity", default: 1, null: false
    t.string "unit", default: "unidad", null: false
    t.decimal "unit_price", precision: 12, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["expense_id"], name: "index_expense_items_on_expense_id"
  end

  create_table "expenses", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.integer "category_id", null: false
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.string "description"
    t.integer "family_group_id", null: false
    t.boolean "is_fixed", default: false, null: false
    t.integer "purchase_channel", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.integer "vendor_id"
    t.index ["category_id"], name: "index_expenses_on_category_id"
    t.index ["family_group_id"], name: "index_expenses_on_family_group_id"
    t.index ["user_id"], name: "index_expenses_on_user_id"
    t.index ["vendor_id"], name: "index_expenses_on_vendor_id"
  end

  create_table "family_groups", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "savings_percentage", default: 0, null: false
    t.datetime "updated_at", null: false
  end

  create_table "financial_tips", force: :cascade do |t|
    t.string "content", null: false
    t.datetime "created_at", null: false
    t.boolean "show_with_alert", default: true, null: false
    t.datetime "updated_at", null: false
  end

  create_table "incomes", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.string "description"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_incomes_on_user_id"
  end

  create_table "installment_purchases", force: :cascade do |t|
    t.integer "category_id", null: false
    t.datetime "created_at", null: false
    t.string "description"
    t.integer "family_group_id", null: false
    t.string "first_period"
    t.integer "installments_count"
    t.decimal "total_amount", precision: 10, scale: 2
    t.datetime "updated_at", null: false
    t.integer "vendor_id"
    t.index ["category_id"], name: "index_installment_purchases_on_category_id"
    t.index ["family_group_id"], name: "index_installment_purchases_on_family_group_id"
    t.index ["vendor_id"], name: "index_installment_purchases_on_vendor_id"
  end

  create_table "reference_indices", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "period", null: false
    t.datetime "updated_at", null: false
    t.decimal "value", precision: 12, scale: 4, null: false
  end

  create_table "savings_goals", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "deadline"
    t.integer "family_group_id", null: false
    t.string "name", null: false
    t.decimal "saved_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "target_amount", precision: 12, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.index ["family_group_id"], name: "index_savings_goals_on_family_group_id"
  end

  create_table "shopping_list_items", force: :cascade do |t|
    t.integer "category_id"
    t.datetime "created_at", null: false
    t.decimal "estimated_unit_price", precision: 10, scale: 2, default: "0.0", null: false
    t.integer "family_group_id", null: false
    t.string "name", null: false
    t.string "period", null: false
    t.decimal "quantity", precision: 10, scale: 2
    t.datetime "updated_at", null: false
    t.index ["category_id"], name: "index_shopping_list_items_on_category_id"
    t.index ["family_group_id"], name: "index_shopping_list_items_on_family_group_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.string "auth_token"
    t.datetime "created_at", null: false
    t.string "email"
    t.integer "family_group_id", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.string "user", null: false
    t.index ["auth_token"], name: "index_users_on_auth_token", unique: true
    t.index ["family_group_id"], name: "index_users_on_family_group_id"
    t.index ["user"], name: "index_users_on_user", unique: true
  end

  create_table "vendors", force: :cascade do |t|
    t.string "category"
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.boolean "online_purchase", default: false, null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "categories", "categories", column: "parent_id"
  add_foreign_key "expense_items", "expenses"
  add_foreign_key "expenses", "categories"
  add_foreign_key "expenses", "family_groups"
  add_foreign_key "expenses", "users"
  add_foreign_key "expenses", "vendors"
  add_foreign_key "incomes", "users"
  add_foreign_key "installment_purchases", "categories"
  add_foreign_key "installment_purchases", "family_groups"
  add_foreign_key "installment_purchases", "vendors"
  add_foreign_key "savings_goals", "family_groups"
  add_foreign_key "shopping_list_items", "categories"
  add_foreign_key "shopping_list_items", "family_groups"
  add_foreign_key "users", "family_groups"
end
