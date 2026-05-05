class DataMigrationsController < ApplicationController
  def index
    @migrations = DataMigration.recent.limit(50)
  end

  def new; end

  def show
    @migration = DataMigration.find(params[:id])
    @errors = @migration.data_migration_errors.order(:line_number).limit(200)
  end
end
