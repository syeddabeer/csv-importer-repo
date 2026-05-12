require "test_helper"

class PatientTest < ActiveSupport::TestCase
  def valid_attrs(overrides = {})
    {
      health_number: "1234567890",
      health_number_province: "ON",
      source_row_digest: "digest-#{SecureRandom.hex(4)}"
    }.merge(overrides)
  end

  test "is valid with minimal required attributes" do
    assert Patient.new(valid_attrs).valid?
  end

  test "requires health_number" do
    patient = Patient.new(valid_attrs(health_number: nil))
    assert_not patient.valid?
    assert_includes patient.errors[:health_number], "can't be blank"
  end

  test "requires health_number_province" do
    patient = Patient.new(valid_attrs(health_number_province: nil))
    assert_not patient.valid?
    assert_includes patient.errors[:health_number_province], "can't be blank"
  end

  test "rejects health_number_province that is not a canadian code" do
    patient = Patient.new(valid_attrs(health_number_province: "XX"))
    assert_not patient.valid?
    assert_includes patient.errors[:health_number_province], "is not included in the list"
  end

  test "accepts any defined SEXES value and nil" do
    Patient::SEXES.each do |s|
      assert Patient.new(valid_attrs(sex: s)).valid?, "expected #{s.inspect} to be valid"
    end
    assert Patient.new(valid_attrs(sex: nil)).valid?
  end

  test "rejects an unknown sex value" do
    patient = Patient.new(valid_attrs(sex: "Z"))
    assert_not patient.valid?
    assert_includes patient.errors[:sex], "is not included in the list"
  end

  test "rejects malformed email but allows blank" do
    assert Patient.new(valid_attrs(email: "")).valid?
    invalid = Patient.new(valid_attrs(email: "not-an-email"))
    assert_not invalid.valid?
    assert_includes invalid.errors[:email], "is invalid"
  end

  test "enforces uniqueness of health_number scoped to province" do
    Patient.create!(valid_attrs(health_number: "9999", health_number_province: "ON"))
    dup = Patient.new(valid_attrs(health_number: "9999", health_number_province: "ON"))
    assert_not dup.valid?
    assert_includes dup.errors[:health_number], "has already been taken"

    different_province = Patient.new(valid_attrs(health_number: "9999", health_number_province: "BC"))
    assert different_province.valid?
  end

  test "normalize_province maps full names to 2-letter codes" do
    assert_equal "ON", Patient.normalize_province("Ontario")
    assert_equal "ON", Patient.normalize_province("ontario")
    assert_equal "BC", Patient.normalize_province("British Columbia")
    assert_equal "NL", Patient.normalize_province("Newfoundland and Labrador")
    assert_equal "QC", Patient.normalize_province("qu\u00e9bec")
    assert_equal "PE", Patient.normalize_province("PEI")
  end

  test "normalize_province passes through canonical codes" do
    assert_equal "ON", Patient.normalize_province("on")
    assert_equal "ON", Patient.normalize_province("ON")
  end

  test "normalize_province returns nil for blank input" do
    assert_nil Patient.normalize_province(nil)
    assert_nil Patient.normalize_province("")
    assert_nil Patient.normalize_province("   ")
  end

  test "normalize_province returns upcased unknown values so validation fails" do
    assert_equal "ZZ", Patient.normalize_province("zz")
  end

  test "before_validation normalizes provinces on the record" do
    patient = Patient.new(valid_attrs(health_number_province: "Ontario", province: "british columbia"))
    patient.valid?
    assert_equal "ON", patient.health_number_province
    assert_equal "BC", patient.province
  end

  test "full_name joins first and last names, ignoring blanks" do
    assert_equal "Jane Doe", Patient.new(first_name: "Jane", last_name: "Doe").full_name
    assert_equal "Jane",     Patient.new(first_name: "Jane", last_name: "").full_name
    assert_equal "Doe",      Patient.new(first_name: nil, last_name: "Doe").full_name
    assert_equal "",         Patient.new.full_name
  end
end
