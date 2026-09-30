class CreateReferenceIndices < ActiveRecord::Migration[7.1]
  def change
    create_table :reference_indices do |t|
      t.string :name, null: false
      t.string :period, null: false
      t.decimal :value, precision: 12, scale: 4, null: false
      t.timestamps
    end
  end
end
