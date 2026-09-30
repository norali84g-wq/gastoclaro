class CreateExpenses < ActiveRecord::Migration[7.1]
  def change
    create_table :expenses do |t|
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.date :date, null: false
      t.references :user, null: false, foreign_key: true
      t.references :family_group, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.references :vendor, null: true, foreign_key: true
      t.integer :purchase_channel, default: 0, null: false
      t.boolean :is_fixed, default: false, null: false
      t.string :description
      t.timestamps
    end
  end
end
