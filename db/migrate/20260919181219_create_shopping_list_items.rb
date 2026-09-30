class CreateShoppingListItems < ActiveRecord::Migration[7.1]
  def change
    create_table :shopping_list_items do |t|
      t.references :family_group, null: false, foreign_key: true
      t.string :name, null: false
      t.string :period, null: false
      t.decimal :quantity, precision: 10, scale: 2, null: false

      t.timestamps
    end
  end
end
