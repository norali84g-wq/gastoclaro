class Api::V1::UsersController < Api::V1::BaseController
  before_action :require_admin!

  def index
    render json: User.order(:id).map { |user|
      { id: user.id, user: user.user, email: user.email, admin: user.admin }
    }
  end
end
