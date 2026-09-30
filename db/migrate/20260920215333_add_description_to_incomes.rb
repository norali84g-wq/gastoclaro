class AddDescriptionToIncomes < ActiveRecord::Migration[8.1]
  def change
    add_column :incomes, :description, :string
  end
end
