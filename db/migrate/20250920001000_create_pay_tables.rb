class CreatePayTables < ActiveRecord::Migration[8.0]
  def change
  create_table :pay_customers do |t|
      t.references :owner, polymorphic: true, null: false
      t.string :processor, null: false
      t.string :processor_id
      t.boolean :default, default: true
  t.json :data
      t.timestamps
    end
    add_index :pay_customers, [ :processor, :processor_id ]

  create_table :pay_subscriptions do |t|
      t.references :customer, null: false, foreign_key: { to_table: :pay_customers }
      t.string :name, null: false
      t.string :processor, null: false
      t.string :processor_id
      t.string :processor_plan
      t.integer :quantity, default: 1
      t.datetime :trial_ends_at
      t.datetime :ends_at
  t.json :data
      t.timestamps
    end
    add_index :pay_subscriptions, [ :processor, :processor_id ]
  end
end
