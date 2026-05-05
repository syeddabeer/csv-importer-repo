class CreateDataMigrations < ActiveRecord::Migration[7.1]
  def change
    create_table :data_migrations do |t|
      t.string   :original_filename
      t.string   :file_digest
      t.integer  :total_rows,     default: 0, null: false
      t.integer  :imported_rows,  default: 0, null: false
      t.integer  :created_rows,   default: 0, null: false
      t.integer  :updated_rows,   default: 0, null: false
      t.integer  :unchanged_rows, default: 0, null: false
      t.integer  :skipped_rows,   default: 0, null: false
      t.integer  :failed_rows,    default: 0, null: false
      t.string   :status,         default: "pending", null: false
      t.datetime :started_at
      t.datetime :finished_at
      t.float    :duration_seconds
      t.text     :error_message
      t.timestamps
    end

    create_table :data_migration_errors do |t|
      t.references :data_migration, null: false, foreign_key: true, index: true
      t.integer    :line_number, null: false
      t.string     :health_number
      t.string     :health_number_province
      t.text       :messages
      t.timestamps
    end
  end
end
