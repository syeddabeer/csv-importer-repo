require "test_helper"

class DataMigrationsControllerTest < ActionDispatch::IntegrationTest
  test "GET /data_migrations renders the recent migrations index" do
    DataMigration.create!(status: "completed", original_filename: "earlier.csv")
    DataMigration.create!(status: "completed", original_filename: "latest.csv")

    get data_migrations_path
    assert_response :success
  end

  test "GET /data_migrations/new renders the upload form" do
    get new_data_migration_path
    assert_response :success
  end

  test "POST /data_migrations without a file re-renders new with an alert" do
    post data_migrations_path, params: {}
    assert_response :unprocessable_entity
    assert_match(/choose a CSV file/i, flash[:alert].to_s)
  end

  test "POST /data_migrations with a valid CSV creates a migration and redirects" do
    csv = "health_number,health_number_province\nE1,ON\n"
    file = Rack::Test::UploadedFile.new(StringIO.new(csv), "text/csv", original_filename: "patients.csv")

    assert_difference -> { DataMigration.count }, 1 do
      post data_migrations_path, params: { file: file }
    end

    migration = DataMigration.order(:id).last
    assert_redirected_to data_migration_path(migration.id)
    assert_equal "completed", migration.status
    assert_equal 1, migration.created_rows
  end

  test "GET /data_migrations/:id renders the show page" do
    migration = DataMigration.create!(status: "completed", original_filename: "x.csv")
    migration.data_migration_errors.create!(line_number: 2, messages: "boom")

    get data_migration_path(migration.id)
    assert_response :success
  end
end
