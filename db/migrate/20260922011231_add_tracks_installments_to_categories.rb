class AddTracksInstallmentsToCategories < ActiveRecord::Migration[8.1]
  def change
    add_column :categories, :tracks_installments, :boolean
  end
end
