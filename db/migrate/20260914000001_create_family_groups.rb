class CreateFamilyGroups < ActiveRecord::Migration[7.1]
  def change
    create_table :family_groups do |t|
      t.string :name, null: false
      t.integer :savings_percentage, default: 0, null: false
      t.timestamps
    end
  end
end
