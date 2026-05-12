require "test_helper"
require "stringio"

class PatientCsvImporterTest < ActiveSupport::TestCase
  def import(csv, filename: "patients.csv")
    PatientCsvImporter.new(io: StringIO.new(csv), original_filename: filename).call
  end

  test "imports a valid CSV and reports created counts" do
    csv = <<~CSV
      Health Number,HIN Province,First Name,Last Name,DOB,Sex,Email,Phone,Address,City,Province,Postal Code,Country
      1111,ON,Jane,Doe,1990-01-15,F,Jane@Example.COM,(416) 555-1234,1 Main St,Toronto,Ontario,M5H 2N2,CA
      2222,BC,John,Smith,1985-06-30,M,john@example.com,604-555-9999,2 Pine Ave,Vancouver,British Columbia,V6B 1A1,CA
    CSV

    result = import(csv)
    migration = result.migration

    assert_equal "completed", migration.status
    assert_equal 2, migration.total_rows
    assert_equal 2, migration.created_rows
    assert_equal 2, migration.imported_rows
    assert_equal 0, migration.failed_rows
    assert_equal 0, migration.skipped_rows
    assert_not_nil migration.duration_seconds
    assert_not_nil migration.file_digest
    assert_equal "patients.csv", migration.original_filename

    jane = Patient.find_by!(health_number: "1111", health_number_province: "ON")
    assert_equal "jane@example.com", jane.email
    assert_equal "ON", jane.province
    assert_equal "F", jane.sex
    assert_equal "4165551234", jane.phone
    assert_equal Date.new(1990, 1, 15), jane.date_of_birth
    assert_equal "Health For You Clinic", jane.source_clinic

    john = Patient.find_by!(health_number: "2222", health_number_province: "BC")
    assert_equal "BC", john.province
    assert_equal "6045559999", john.phone
  end

  test "is idempotent when re-importing identical data" do
    csv = <<~CSV
      health_number,health_number_province,first_name
      A1,ON,Alice
    CSV

    first = import(csv).migration
    assert_equal 1, first.created_rows
    assert_equal 1, Patient.count

    second = import(csv).migration
    assert_equal 0, second.created_rows
    assert_equal 0, second.updated_rows
    assert_equal 1, second.unchanged_rows
    assert_equal 1, Patient.count
  end

  test "detects updates when fields change between imports" do
    import(<<~CSV).migration
      health_number,health_number_province,first_name
      B2,ON,Bob
    CSV

    result = import(<<~CSV).migration
      health_number,health_number_province,first_name
      B2,ON,Robert
    CSV

    assert_equal 0, result.created_rows
    assert_equal 1, result.updated_rows
    assert_equal "Robert", Patient.find_by(health_number: "B2").first_name
  end

  test "skips rows missing health_number or province and records errors" do
    csv = <<~CSV
      health_number,health_number_province,first_name
      ,ON,NoNumber
      C3,,NoProvince
      C4,ON,Valid
    CSV

    migration = import(csv).migration

    assert_equal 3, migration.total_rows
    assert_equal 2, migration.skipped_rows
    assert_equal 1, migration.created_rows
    assert_equal 2, migration.data_migration_errors.count

    error_lines = migration.data_migration_errors.pluck(:line_number).sort
    assert_equal [2, 3], error_lines
  end

  test "records failures for rows whose normalized data fails validation" do
    csv = <<~CSV
      health_number,health_number_province,first_name,email
      D4,ON,Dave,not-an-email
    CSV

    migration = import(csv).migration

    assert_equal 1, migration.failed_rows
    assert_equal 0, migration.created_rows
    assert_equal 1, migration.data_migration_errors.count
    err = migration.data_migration_errors.first
    assert_match(/Email/i, err.messages)
  end

  test "marks migration failed when required columns are missing" do
    csv = <<~CSV
      first_name,last_name
      Jane,Doe
    CSV

    migration = import(csv).migration

    assert_equal "failed", migration.status
    assert_match(/Missing required columns/, migration.error_message)
  end

  test "accepts alternate header names via column aliases" do
    csv = <<~CSV
      HIN,Province of HIN,Given Name,Surname,Birth Date,Gender,E-mail,Telephone
      Z9,Ontario,Zoe,Last,1970-12-31,Female,zoe@example.com,123-456-7890
    CSV

    migration = import(csv).migration

    assert_equal "completed", migration.status
    assert_equal 1, migration.created_rows
    patient = Patient.find_by(health_number: "Z9")
    assert_equal "ON", patient.health_number_province
    assert_equal "F", patient.sex
    assert_equal "Zoe", patient.first_name
    assert_equal Date.new(1970, 12, 31), patient.date_of_birth
  end

  test "normalizes various sex inputs to canonical codes" do
    csv = <<~CSV
      health_number,health_number_province,sex
      S1,ON,Male
      S2,ON,female
      S3,ON,non-binary
      S4,ON,unknown-value
    CSV

    import(csv)

    assert_equal "M", Patient.find_by(health_number: "S1").sex
    assert_equal "F", Patient.find_by(health_number: "S2").sex
    assert_equal "X", Patient.find_by(health_number: "S3").sex
    assert_equal "U", Patient.find_by(health_number: "S4").sex
  end

  test "tolerates invalid UTF-8 bytes in the source" do
    csv = "health_number,health_number_province,first_name\nU1,ON,Caf\xE9\n".dup.force_encoding("ASCII-8BIT")
    migration = import(csv).migration
    assert_equal "completed", migration.status
    assert_equal 1, migration.created_rows
  end

  test "ignores rows with invalid dates without failing the migration" do
    csv = <<~CSV
      health_number,health_number_province,date_of_birth
      DT1,ON,not-a-date
    CSV

    migration = import(csv).migration
    assert_equal "completed", migration.status
    assert_equal 1, migration.created_rows
    assert_nil Patient.find_by(health_number: "DT1").date_of_birth
  end
end
