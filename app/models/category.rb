class Category < ApplicationRecord
  belongs_to :parent, class_name: "Category", optional: true
  has_many :subcategories, class_name: "Category", foreign_key: :parent_id, dependent: :nullify
  has_many :expenses
  has_many :installment_purchases, dependent: :destroy

  validates :name, presence: true
end
