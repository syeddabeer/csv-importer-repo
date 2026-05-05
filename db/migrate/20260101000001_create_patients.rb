class CreatePatients < ActiveRecord::Migration[7.1]
  def change
    create_table :patients do |t|
      t.string  :health_number,          null: false
      t.string  :health_number_province, null: false
      t.string  :first_name
      t.string  :last_name
      t.date    :date_of_birth
      t.string  :sex
      t.string  :email
      t.string  :phone
      t.string  :address_line
      t.string  :city
      t.string  :province
      t.string  :postal_code
      t.string  :country
      t.string  :source_clinic
      t.string  :source_row_digest, null: false
      t.timestamps
    end

    add_index :patients,
              %i[health_number health_number_province],
              unique: true,
              name: "index_patients_on_health_id"
  end
end
