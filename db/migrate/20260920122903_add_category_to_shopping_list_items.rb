class AddCategoryToShoppingListItems < ActiveRecord::Migration[8.1]
  def change
    add_reference :shopping_list_items, :category, foreign_key: true
  end
end
