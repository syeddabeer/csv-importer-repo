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

ActiveRecord::Schema[7.1].define(version: 2026_01_01_000002) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "data_migration_errors", force: :cascade do |t|
    t.bigint "data_migration_id", null: false
    t.integer "line_number", null: false
    t.string "health_number"
    t.string "health_number_province"
    t.text "messages"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["data_migration_id"], name: "index_data_migration_errors_on_data_migration_id"
  end

  create_table "data_migrations", force: :cascade do |t|
    t.string "original_filename"
    t.string "file_digest"
    t.integer "total_rows", default: 0, null: false
    t.integer "imported_rows", default: 0, null: false
    t.integer "created_rows", default: 0, null: false
    t.integer "updated_rows", default: 0, null: false
    t.integer "unchanged_rows", default: 0, null: false
    t.integer "skipped_rows", default: 0, null: false
    t.integer "failed_rows", default: 0, null: false
    t.string "status", default: "pending", null: false
    t.datetime "started_at"
    t.datetime "finished_at"
    t.float "duration_seconds"
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "patients", force: :cascade do |t|
    t.string "health_number", null: false
    t.string "health_number_province", null: false
    t.string "first_name"
    t.string "last_name"
    t.date "date_of_birth"
    t.string "sex"
    t.string "email"
    t.string "phone"
    t.string "address_line"
    t.string "city"
    t.string "province"
    t.string "postal_code"
    t.string "country"
    t.string "source_clinic"
    t.string "source_row_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["health_number", "health_number_province"], name: "index_patients_on_health_id", unique: true
  end

  add_foreign_key "data_migration_errors", "data_migrations"
end
