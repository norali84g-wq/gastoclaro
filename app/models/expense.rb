class Expense < ApplicationRecord
  belongs_to :user
  belongs_to :family_group
  belongs_to :category
  belongs_to :vendor, optional: true
  has_many :expense_items, dependent: :destroy
  has_one_attached :receipt_image

  accepts_nested_attributes_for :expense_items, allow_destroy: true, reject_if: proc { |attrs| attrs["name"].blank? }

  enum :purchase_channel, { presencial: 0, delivery: 1, retiro: 2 }, default: :presencial

  scope :fixed, -> { where(is_fixed: true) }
  scope :variable, -> { where(is_fixed: false) }

  validates :amount, numericality: { greater_than: 0 }
  validates :date, presence: true

  before_validation :set_family_group_from_user
  before_validation :set_amount_from_items

  private

  def set_family_group_from_user
    self.family_group_id ||= user&.family_group_id
  end

  def set_amount_from_items
    items_total = expense_items.reject(&:marked_for_destruction?).sum { |item| (item.quantity || 0) * (item.unit_price || 0) }
    self.amount = items_total if items_total > 0
  end
end
