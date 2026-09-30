class ChangeQuantityNullOnShoppingListItems < ActiveRecord::Migration[8.1]
  def change
    change_column_null :shopping_list_items, :quantity, true
  end
end
