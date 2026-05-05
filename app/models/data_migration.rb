class DataMigration < ApplicationRecord
  STATUSES = %w[pending running completed failed].freeze

  has_many :data_migration_errors, dependent: :destroy

  validates :status, inclusion: { in: STATUSES }

  scope :recent, -> { order(created_at: :desc) }

  def success_rate
    return 0.0 if total_rows.zero?

    ((imported_rows.to_f / total_rows) * 100).round(2)
  end

  def duration_display
    return "—" unless duration_seconds

    if duration_seconds < 1
      "#{(duration_seconds * 1000).round} ms"
    else
      "#{duration_seconds.round(2)} s"
    end
  end
end
