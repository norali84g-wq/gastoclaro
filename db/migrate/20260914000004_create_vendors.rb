class CreateVendors < ActiveRecord::Migration[7.1]
  def change
    create_table :vendors do |t|
      t.string :name, null: false
      t.string :category
      t.boolean :online_purchase, default: false, null: false
      t.timestamps
    end
  end
end
