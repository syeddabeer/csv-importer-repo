# Temporary placeholder so the UI renders before the real
# ActiveRecord model + DB tables are introduced in the next step.
# Will be replaced by `class DataMigration < ApplicationRecord` once
# the patients / data_migrations tables exist.
class DataMigration
  ATTRS = %i[
    id original_filename status started_at finished_at file_digest
    error_message total_rows imported_rows created_rows updated_rows
    unchanged_rows skipped_rows failed_rows
  ].freeze

  attr_accessor(*ATTRS)

  def self.recent = self
  def self.limit(_n) = []

  def self.find(id)
    new.tap do |m|
      m.id = id.to_i
      m.original_filename = "(not yet implemented)"
      m.status = "pending"
      m.started_at = nil
      m.finished_at = nil
      m.file_digest = nil
      m.error_message = nil
      m.total_rows = 0
      m.imported_rows = 0
      m.created_rows = 0
      m.updated_rows = 0
      m.unchanged_rows = 0
      m.skipped_rows = 0
      m.failed_rows = 0
    end
  end

  def duration_display = "—"
  def success_rate = 0
  def data_migration_errors = self
  def order(_col) = self
  def limit(_n) = []
  def any? = false
end
