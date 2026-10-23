class ReplaceAuthTokenWithTokenVersionOnUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :token_version, :integer, default: 0, null: false
    remove_index :users, :auth_token, unique: true
    remove_column :users, :auth_token, :string
  end
end
