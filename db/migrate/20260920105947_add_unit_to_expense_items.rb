class AddUnitToExpenseItems < ActiveRecord::Migration[7.1]
  def change
    add_column :expense_items, :unit, :string, null: false, default: "unidad"
  end
end
