class AddUniqueIndexToUsersEmail < ActiveRecord::Migration[8.1]
  def change
    add_index :users, :email,
              unique: true,
              where: "email IS NOT NULL AND email != ''",
              name: "index_users_on_email_unique"
  end
end
