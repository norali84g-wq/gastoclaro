class CreateSavingsGoals < ActiveRecord::Migration[7.1]
  def change
    create_table :savings_goals do |t|
      t.references :family_group, null: false, foreign_key: true
      t.string :name, null: false
      t.decimal :target_amount, precision: 12, scale: 2, null: false
      t.decimal :saved_amount, precision: 12, scale: 2, default: "0.0", null: false
      t.date :deadline
      t.timestamps
    end
  end
end
