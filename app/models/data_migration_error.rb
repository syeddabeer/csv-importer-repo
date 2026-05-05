class DataMigrationError < ApplicationRecord
  belongs_to :data_migration

  def message_list
    messages.to_s.split("\n")
  end
end
