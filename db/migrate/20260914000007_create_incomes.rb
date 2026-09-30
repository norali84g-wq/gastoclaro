class CreateIncomes < ActiveRecord::Migration[7.1]
  def change
    create_table :incomes do |t|
      t.references :user, null: false, foreign_key: true
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.date :date, null: false
      t.timestamps
    end
  end
end
