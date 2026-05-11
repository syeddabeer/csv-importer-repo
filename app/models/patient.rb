class Patient < ApplicationRecord
  SEXES = %w[F M X U].freeze
  CANADIAN_PROVINCES = %w[AB BC MB NB NL NS NT NU ON PE QC SK YT].freeze

  # Maps full Canadian province / territory names (and common variants) to
  # their 2-letter postal codes. The model accepts either form on input
  # (`"Ontario"` or `"ON"`) and always stores the canonical code, so the
  # unique index on `(health_number, health_number_province)` stays
  # meaningful regardless of which form a caller supplies.
  PROVINCE_NAMES = {
    "ALBERTA"                   => "AB",
    "BRITISH COLUMBIA"          => "BC",
    "MANITOBA"                  => "MB",
    "NEW BRUNSWICK"             => "NB",
    "NEWFOUNDLAND"              => "NL",
    "NEWFOUNDLAND AND LABRADOR" => "NL",
    "NOVA SCOTIA"               => "NS",
    "NORTHWEST TERRITORIES"     => "NT",
    "NUNAVUT"                   => "NU",
    "ONTARIO"                   => "ON",
    "PRINCE EDWARD ISLAND"      => "PE",
    "PEI"                       => "PE",
    "QUEBEC"                    => "QC",
    "QU\u00C9BEC"               => "QC",
    "SASKATCHEWAN"              => "SK",
    "YUKON"                     => "YT",
    "YUKON TERRITORY"           => "YT"
  }.freeze

  before_validation :normalize_provinces

  validates :health_number, presence: true
  validates :health_number_province, presence: true,
                                     inclusion: { in: CANADIAN_PROVINCES, allow_blank: false }
  validates :health_number, uniqueness: { scope: :health_number_province }
  validates :sex, inclusion: { in: SEXES, allow_nil: true }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }

  # Accepts either a 2-letter code (`"on"`, `"ON"`) or a full name
  # (`"Ontario"`, `"british columbia"`, `"Newfoundland and Labrador"`)
  # and returns the canonical 2-letter code. Unknown values are upcased
  # and returned as-is so the inclusion validation surfaces a clear error.
  def self.normalize_province(value)
    return nil if value.blank?

    key = value.to_s.strip.upcase.gsub(/[\s_-]+/, " ")
    PROVINCE_NAMES[key] || key
  end

  def full_name
    [first_name, last_name].compact_blank.join(" ")
  end

  private

  def normalize_provinces
    self.health_number_province = self.class.normalize_province(health_number_province)
    self.province               = self.class.normalize_province(province)
  end
end
