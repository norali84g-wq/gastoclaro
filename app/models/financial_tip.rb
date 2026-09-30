class FinancialTip < ApplicationRecord
  validates :content, presence: true

  scope :for_alert, -> { where(show_with_alert: true) }
end
