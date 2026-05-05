class DataMigrationsController < ApplicationController
  def index
    @migrations = DataMigration.recent.limit(50)
  end

  def new; end

  def create
    file = params[:file]
    if file.blank?
      flash.now[:alert] = "Please choose a CSV file to upload."
      return render :new, status: :unprocessable_entity
    end

    result = PatientCsvImporter.new(
      io: file.tempfile,
      original_filename: file.original_filename
    ).call

    redirect_to data_migration_path(result.migration.id),
                notice: "Migration ##{result.migration.id} #{result.migration.status}."
  end

  def show
    @migration = DataMigration.find(params[:id])
    @errors = @migration.data_migration_errors.order(:line_number).limit(200)
  end
end
