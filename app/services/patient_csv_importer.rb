require "csv"
require "digest"

# Idempotent CSV importer for patient demographics.
#
# Idempotency strategy
# --------------------
# A patient is uniquely identified by (health_number, health_number_province) —
# the database enforces this with a unique index. We use ActiveRecord's
# `find_or_initialize_by` and only persist when the incoming attributes
# actually differ from what is already stored. Re-running the same file
# therefore produces identical DB state and reports every row as "unchanged".
#
# Header mapping
# --------------
# Source systems rarely use stable column names. Each known field has a list
# of regex aliases so the importer survives reasonable variation
# (e.g. "Health #", "HealthNumber", "health_no").
class PatientCsvImporter
  COLUMN_ALIASES = {
    health_number:          [/\Ahealth[\s_-]*(number|no|num|id|identifier|#)\z/i, /\Ahin\z/i, /\Aphn\z/i],
    health_number_province: [/health.*province/i, /\Aprovince[\s_-]*of[\s_-]*(origin|hin|health)/i, /\Ahin[\s_-]*province/i],
    first_name:             [/\Afirst[\s_-]*name\z/i, /\Agiven[\s_-]*name\z/i],
    last_name:              [/\Alast[\s_-]*name\z/i, /\A(sur|family)[\s_-]*name\z/i],
    date_of_birth:          [/\A(date[\s_-]*of[\s_-]*birth|dob|birth[\s_-]*date)\z/i],
    sex:                    [/\A(sex|gender)\z/i],
    email:                  [/\A(e[\s_-]*mail|email[\s_-]*address)\z/i],
    phone:                  [/\A(phone|telephone|phone[\s_-]*number|mobile|cell)\z/i],
    address_line:           [/\A(address|street|address[\s_-]*line|address[\s_-]*1|address[\s_-]*line[\s_-]*1)\z/i],
    city:                   [/\A(address[\s_-]*)?(city|town|municipality)\z/i],
    province:               [/\A(address[\s_-]*)?(province|state|region)\z/i],
    postal_code:            [/\A(address[\s_-]*)?(postal[\s_-]*code|zip|zip[\s_-]*code)\z/i],
    country:                [/\Acountry\z/i]
  }.freeze

  TRACKED_ATTRS = (COLUMN_ALIASES.keys - %i[]).freeze

  Result = Struct.new(:migration, keyword_init: true)

  def initialize(io:, original_filename:, source_clinic: "Health For You Clinic")
    @io = io
    @original_filename = original_filename
    @source_clinic = source_clinic
  end

  def call
    raw = @io.read
    raw = raw.dup.force_encoding("UTF-8")
    raw.scrub!("?") # Replace invalid UTF-8 bytes so CSV parsing doesn't blow up.

    migration = DataMigration.create!(
      original_filename: @original_filename,
      file_digest: Digest::SHA256.hexdigest(raw),
      status: "running",
      started_at: Time.current
    )

    begin
      table = CSV.parse(raw, headers: true, skip_blanks: true)
      header_map = build_header_map(table.headers)

      missing = required_missing(header_map)
      Rails.logger.error("PatientCsvImporter: Missing required columns: #{missing.join(', ')}") if missing.any?
      raise ArgumentError, "Missing required columns: #{missing.join(', ')}" if missing.any?

      stats = { total: 0, created: 0, updated: 0, unchanged: 0, skipped: 0, failed: 0 }

      table.each.with_index(2) do |csv_row, line_number|
        stats[:total] += 1

        attrs = extract_attrs(csv_row, header_map)

        if attrs[:health_number].blank? || attrs[:health_number_province].blank?
          stats[:skipped] += 1
          record_error(migration, line_number, attrs,
                       ["Missing health_number or health_number_province"])
          next
        end

        outcome = upsert(attrs)

        case outcome[:status]
        when :created   then stats[:created] += 1
        when :updated   then stats[:updated] += 1
        when :unchanged then stats[:unchanged] += 1
        when :failed
          stats[:failed] += 1
          record_error(migration, line_number, attrs, outcome[:errors])
        end
      end

      finished = Time.current
      migration.update!(
        total_rows:     stats[:total],
        created_rows:   stats[:created],
        updated_rows:   stats[:updated],
        unchanged_rows: stats[:unchanged],
        skipped_rows:   stats[:skipped],
        failed_rows:    stats[:failed],
        imported_rows:  stats[:created] + stats[:updated] + stats[:unchanged],
        status:         "completed",
        finished_at:    finished,
        duration_seconds: (finished - migration.started_at).to_f
      )
    rescue StandardError => e
      finished = Time.current
      migration.update!(
        status: "failed",
        error_message: "#{e.class}: #{e.message}",
        finished_at: finished,
        duration_seconds: (finished - migration.started_at).to_f
      )
    end

    Result.new(migration: migration)
  end

  private

  def build_header_map(headers)
    map = {}
    COLUMN_ALIASES.each do |attr, patterns|
      header = headers.find { |h| h && patterns.any? { |p| h.to_s.strip.match?(p) } }
      map[attr] = header if header
    end
    map
  end

  def required_missing(header_map)
    %i[health_number health_number_province] - header_map.keys
  end

  def extract_attrs(csv_row, header_map)
    attrs = {}
    header_map.each do |attr, source_header|
      attrs[attr] = csv_row[source_header].to_s.strip.presence
    end
    attrs[:health_number_province] = Patient.normalize_province(attrs[:health_number_province])
    attrs[:province]               = Patient.normalize_province(attrs[:province])
    attrs[:sex] = normalize_sex(attrs[:sex])
    attrs[:date_of_birth] = parse_date(attrs[:date_of_birth])
    attrs[:email] = attrs[:email]&.downcase
    attrs[:phone] = normalize_phone(attrs[:phone])
    attrs
  end

  # Accepts either a 2-letter code ("on", "ON") or a full name
  # ("Ontario", "british columbia") and returns the canonical 2-letter
  # code. Unknown values are upcased and returned as-is so that the model's
  # inclusion validation surfaces a clear error.
  def normalize_province(value)
    return nil if value.blank?

    key = value.strip.upcase.gsub(/[\s_-]+/, " ")
    PROVINCE_NAMES[key] || key
  end

  def normalize_sex(value)
    return nil if value.blank?

    case value.strip.upcase
    when "F", "FEMALE" then "F"
    when "M", "MALE"   then "M"
    when "X", "OTHER", "NON-BINARY", "NB" then "X"
    else "U"
    end
  end

  def parse_date(value)
    return nil if value.blank?

    Date.parse(value)
  rescue ArgumentError
    nil
  end

  def normalize_phone(value)
    return nil if value.blank?

    digits = value.gsub(/\D/, "")
    digits.presence
  end

  def upsert(attrs)
    patient = Patient.find_or_initialize_by(
      health_number:          attrs[:health_number],
      health_number_province: attrs[:health_number_province]
    )

    new_record = patient.new_record?
    patient.assign_attributes(attrs.except(:health_number, :health_number_province))
    patient.source_clinic = @source_clinic
    patient.source_row_digest = Digest::SHA256.hexdigest(attrs.to_a.sort.to_s)

    if !new_record && !patient.changed?
      return { status: :unchanged }
    end

    if patient.save
      { status: new_record ? :created : :updated }
    else
      { status: :failed, errors: patient.errors.full_messages }
    end
  end

  def record_error(migration, line_number, attrs, messages)
    migration.data_migration_errors.create!(
      line_number: line_number,
      health_number: attrs[:health_number],
      health_number_province: attrs[:health_number_province],
      messages: messages.join("\n")
    )
  end
end
