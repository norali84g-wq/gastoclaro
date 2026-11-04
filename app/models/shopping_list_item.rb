class ShoppingListItem < ApplicationRecord
  belongs_to :family_group
  belongs_to :category

  validates :name, presence: true
  validates :period, presence: true, format: { with: /\A\d{4}-(0[1-9]|1[0-2])\z/, message: "debe tener formato AAAA-MM" }
  validates :quantity, numericality: { greater_than: 0 }, allow_nil: true
  validates :estimated_unit_price, numericality: { greater_than_or_equal_to: 0 }

  def subtotal
    (quantity || 0) * (estimated_unit_price || 0)
  end
end
