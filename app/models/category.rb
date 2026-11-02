class Category < ApplicationRecord
  belongs_to :parent, class_name: "Category", optional: true
  has_many :subcategories, class_name: "Category", foreign_key: :parent_id, dependent: :nullify
  has_many :expenses
  has_many :installment_purchases, dependent: :destroy

  validates :name, presence: true
  validate :parent_is_not_self_or_descendant

  # Ids de todas las subcategorías de esta categoría, de cualquier nivel. Si los datos ya tuvieran un
  # ciclo, no se repite ningún id, así que siempre termina.
  def descendant_ids
    return [] if new_record?

    found = []
    pending = [ id ]
    while pending.any?
      children = Category.where(parent_id: pending).where.not(id: found).pluck(:id)
      found.concat(children)
      pending = children
    end
    found
  end

  private

  # Una categoría no puede ser su propio padre ni colgar de una de sus subcategorías: se formaría un
  # ciclo y la categoría dejaría de aparecer entre las raíces.
  def parent_is_not_self_or_descendant
    return if parent_id.blank? || new_record?

    if parent_id == id || descendant_ids.include?(parent_id)
      errors.add(:parent_id, "no puede ser la propia categoría ni una de sus subcategorías")
    end
  end
end
