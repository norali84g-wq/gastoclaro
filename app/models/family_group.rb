class FamilyGroup < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :expenses, dependent: :destroy
  has_many :savings_goals, dependent: :destroy
  has_many :installment_purchases, dependent: :destroy

  validates :name, presence: true
  validates :savings_percentage, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }
end
