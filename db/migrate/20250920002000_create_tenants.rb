class CreateTenants < ActiveRecord::Migration[8.0]
  def change
    create_table :tenants do |t|
      t.string :subdomain, null: false
      t.string :name
      t.timestamps
    end
    add_index :tenants, 'LOWER(subdomain)', unique: true, name: 'index_tenants_on_lower_subdomain'
  end
end
