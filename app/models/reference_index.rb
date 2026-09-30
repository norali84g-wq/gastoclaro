class ReferenceIndex < ApplicationRecord
  validates :name, presence: true
  validates :period, presence: true
  validates :value, numericality: true
end
