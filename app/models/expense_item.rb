class ExpenseItem < ApplicationRecord
  belongs_to :expense

  validates :name, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :unit_price, numericality: { greater_than_or_equal_to: 0 }
  validates :unit, inclusion: { in: %w[unidad kg g] }

  def subtotal
    quantity * unit_price
  end
end
