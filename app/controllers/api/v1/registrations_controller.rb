class Api::V1::RegistrationsController < Api::V1::BaseController
  skip_before_action :authenticate_user!, only: [ :create ]

  def create
    user = RegisterUser.call(registration_params)

    if user.persisted?
      render json: SessionSerializer.call(user), status: :created
    else
      render json: { errors: user.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.permit(:user, :email, :password, :password_confirmation)
  end
end
