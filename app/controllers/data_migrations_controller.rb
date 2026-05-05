class DataMigrationsController < ApplicationController
  def index
    @migrations = DataMigration.recent.limit(50)
  end

  def new; end
end
