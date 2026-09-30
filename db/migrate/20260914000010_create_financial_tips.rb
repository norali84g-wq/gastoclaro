class CreateFinancialTips < ActiveRecord::Migration[7.1]
  def change
    create_table :financial_tips do |t|
      t.string :content, null: false
      t.boolean :show_with_alert, default: true, null: false
      t.timestamps
    end
  end
end
