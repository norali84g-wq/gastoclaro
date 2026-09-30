class CreateUsers < ActiveRecord::Migration[7.1]
  def change
    create_table :users do |t|
      t.string :user, null: false
      t.string :password_digest, null: false
      t.references :family_group, null: false, foreign_key: true
      t.string :auth_token
      t.boolean :admin, default: false, null: false
      t.timestamps
    end
    add_index :users, :user, unique: true
    add_index :users, :auth_token, unique: true
  end
end
