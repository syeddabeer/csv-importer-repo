class Patient < ApplicationRecord
  SEXES = %w[F M X U].freeze
  CANADIAN_PROVINCES = %w[AB BC MB NB NL NS NT NU ON PE QC SK YT].freeze

  validates :health_number, presence: true
  validates :health_number_province, presence: true,
                                     inclusion: { in: CANADIAN_PROVINCES, allow_blank: false }
  validates :health_number, uniqueness: { scope: :health_number_province }
  validates :sex, inclusion: { in: SEXES, allow_nil: true }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }

  def full_name
    [first_name, last_name].compact_blank.join(" ")
  end
end
