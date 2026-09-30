class CreateInstallmentPurchases < ActiveRecord::Migration[8.1]
  def change
    create_table :installment_purchases do |t|
      t.references :family_group, null: false, foreign_key: true
      t.references :category, null: false, foreign_key: true
      t.references :vendor, null: false, foreign_key: true
      t.string :description
      t.decimal :total_amount, precision: 10, scale: 2
      t.integer :installments_count
      t.string :first_period

      t.timestamps
    end
  end
end
