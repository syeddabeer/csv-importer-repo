require "test_helper"

class DataMigrationErrorTest < ActiveSupport::TestCase
  test "belongs to a data_migration" do
    error = DataMigrationError.new(line_number: 2, messages: "x")
    assert_not error.valid?
    assert_includes error.errors[:data_migration], "must exist"
  end

  test "message_list splits messages on newlines" do
    error = DataMigrationError.new(messages: "first error\nsecond error")
    assert_equal ["first error", "second error"], error.message_list
  end

  test "message_list returns an empty array when messages is nil" do
    assert_equal [], DataMigrationError.new(messages: nil).message_list
  end
end
