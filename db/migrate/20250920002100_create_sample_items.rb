class CreateSampleItems < ActiveRecord::Migration[8.0]
  def change
    create_table :sample_items do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :name, null: false
      t.timestamps
    end
  end
end
