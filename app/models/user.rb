class User < ApplicationRecord
  has_secure_password

  belongs_to :family_group
  has_many :expenses, dependent: :destroy
  has_many :incomes, dependent: :destroy

  validates :user, presence: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  before_create :generate_auth_token

  private

  def generate_auth_token
    self.auth_token = SecureRandom.hex(20)
  end
end
