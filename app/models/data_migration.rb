# Temporary placeholder so the index page renders before the real
# ActiveRecord model + migration are introduced in the next step.
# Will be replaced by `class DataMigration < ApplicationRecord` once
# the patients / data_migrations tables exist.
class DataMigration
  def self.recent
    self
  end

  def self.limit(_n)
    []
  end
end
