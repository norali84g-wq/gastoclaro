class CreateExpenseItems < ActiveRecord::Migration[7.1]
  def change
    create_table :expense_items do |t|
      t.references :expense, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :quantity, default: 1, null: false
      t.decimal :unit_price, precision: 12, scale: 2, null: false
      t.timestamps
    end
  end
end
