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

ActiveRecord::Schema.define(version: 2021_11_03_101514) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "auth_requests", force: :cascade do |t|
    t.string "oauth_state", null: false
    t.string "oidc_nonce", null: false
    t.string "redirect_path"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "email_subscriptions", force: :cascade do |t|
    t.bigint "oidc_user_id", null: false
    t.string "name", null: false
    t.string "topic_slug", null: false
    t.string "email_alert_api_subscription_id"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
    t.index ["oidc_user_id", "name"], name: "index_email_subscriptions_on_oidc_user_id_and_name", unique: true
    t.index ["oidc_user_id"], name: "index_email_subscriptions_on_oidc_user_id"
  end

  create_table "oidc_users", force: :cascade do |t|
    t.string "sub", null: false
    t.datetime "created_at", precision: 6, default: -> { "now()" }, null: false
    t.datetime "updated_at", precision: 6, default: -> { "now()" }, null: false
    t.boolean "has_received_transition_checker_onboarding_email", default: false, null: false
    t.string "email"
    t.boolean "email_verified"
    t.boolean "has_unconfirmed_email"
    t.boolean "oidc_users"
    t.jsonb "transition_checker_state"
    t.string "legacy_sub"
    t.boolean "cookie_consent"
    t.boolean "feedback_consent"
    t.index ["email"], name: "index_oidc_users_on_email", unique: true
    t.index ["legacy_sub"], name: "index_oidc_users_on_legacy_sub", unique: true
    t.index ["sub"], name: "index_oidc_users_on_sub", unique: true
  end

  create_table "tombstones", force: :cascade do |t|
    t.string "sub", null: false
    t.datetime "created_at", precision: 6, default: -> { "now()" }, null: false
    t.datetime "updated_at", precision: 6, default: -> { "now()" }, null: false
    t.index ["sub"], name: "index_tombstones_on_sub", unique: true
  end

  create_table "unmigrated_oidc_users", force: :cascade do |t|
    t.string "sub", null: false
    t.string "email"
    t.boolean "email_verified"
    t.boolean "has_unconfirmed_email"
    t.jsonb "transition_checker_state"
    t.datetime "created_at", precision: 6, default: -> { "now()" }, null: false
    t.datetime "updated_at", precision: 6, default: -> { "now()" }, null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "uid"
    t.string "organisation_slug"
    t.string "organisation_content_id"
    t.string "app_name"
    t.text "permissions"
    t.boolean "remotely_signed_out", default: false
    t.boolean "disabled", default: false
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

end
