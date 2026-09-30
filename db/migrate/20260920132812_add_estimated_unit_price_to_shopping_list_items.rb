class AddEstimatedUnitPriceToShoppingListItems < ActiveRecord::Migration[8.1]
  def change
    add_column :shopping_list_items, :estimated_unit_price, :decimal, precision: 10, scale: 2, default: 0, null: false
  end
end
