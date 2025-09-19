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

ActiveRecord::Schema[8.0].define(version: 2025_09_20_001000) do
  create_table "pay_customers", force: :cascade do |t|
    t.string "owner_type", null: false
    t.integer "owner_id", null: false
    t.string "processor", null: false
    t.string "processor_id"
    t.boolean "default", default: true
    t.json "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_type", "owner_id"], name: "index_pay_customers_on_owner"
    t.index ["processor", "processor_id"], name: "index_pay_customers_on_processor_and_processor_id"
  end

  create_table "pay_subscriptions", force: :cascade do |t|
    t.integer "customer_id", null: false
    t.string "name", null: false
    t.string "processor", null: false
    t.string "processor_id"
    t.string "processor_plan"
    t.integer "quantity", default: 1
    t.datetime "trial_ends_at"
    t.datetime "ends_at"
    t.json "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_pay_subscriptions_on_customer_id"
    t.index ["processor", "processor_id"], name: "index_pay_subscriptions_on_processor_and_processor_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "pay_subscriptions", "pay_customers", column: "customer_id"
end
