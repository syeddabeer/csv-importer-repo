require "test_helper"

class DataMigrationTest < ActiveSupport::TestCase
  test "validates status inclusion" do
    DataMigration::STATUSES.each do |s|
      assert DataMigration.new(status: s).valid?, "expected #{s} to be a valid status"
    end
    invalid = DataMigration.new(status: "bogus")
    assert_not invalid.valid?
    assert_includes invalid.errors[:status], "is not included in the list"
  end

  test "has_many data_migration_errors and destroys them with the migration" do
    migration = DataMigration.create!(status: "completed")
    migration.data_migration_errors.create!(line_number: 2, messages: "bad row")
    assert_equal 1, migration.data_migration_errors.count

    assert_difference -> { DataMigrationError.count }, -1 do
      migration.destroy
    end
  end

  test "recent scope orders by created_at descending" do
    older = DataMigration.create!(status: "completed", created_at: 2.days.ago)
    newer = DataMigration.create!(status: "completed", created_at: 1.day.ago)
    newest = DataMigration.create!(status: "completed")

    assert_equal [newest.id, newer.id, older.id], DataMigration.recent.pluck(:id).first(3)
  end

  test "success_rate returns 0.0 when no rows" do
    assert_equal 0.0, DataMigration.new(total_rows: 0, imported_rows: 0).success_rate
  end

  test "success_rate computes percentage rounded to 2 decimals" do
    migration = DataMigration.new(total_rows: 8, imported_rows: 3)
    assert_equal 37.5, migration.success_rate

    migration2 = DataMigration.new(total_rows: 3, imported_rows: 1)
    assert_equal 33.33, migration2.success_rate
  end

  test "duration_display formats ms for sub-second durations" do
    assert_equal "250 ms", DataMigration.new(duration_seconds: 0.25).duration_display
  end

  test "duration_display formats seconds for >= 1s" do
    assert_equal "1.5 s", DataMigration.new(duration_seconds: 1.5).duration_display
    assert_equal "12.35 s", DataMigration.new(duration_seconds: 12.3456).duration_display
  end

  test "duration_display returns em-dash when nil" do
    assert_equal "\u2014", DataMigration.new(duration_seconds: nil).duration_display
  end
end
