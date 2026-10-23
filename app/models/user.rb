class User < ApplicationRecord
  PASSWORD_MIN_LENGTH = 8

  has_secure_password

  belongs_to :family_group
  has_many :expenses, dependent: :destroy
  has_many :incomes, dependent: :destroy

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :user, presence: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: true, allow_blank: true
  validates :email, presence: true, on: :registration
  validates :password, length: { minimum: PASSWORD_MIN_LENGTH }, on: :registration
  validates :password_confirmation, presence: true, on: :registration

  before_create :generate_auth_token

  private

  def generate_auth_token
    self.auth_token = SecureRandom.hex(20)
  end
end
