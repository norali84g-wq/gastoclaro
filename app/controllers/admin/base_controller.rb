class Admin::BaseController < ApplicationController
  layout "admin"
  before_action :require_admin

  private

  def require_admin
    unless session[:admin_user_id]
      redirect_to admin_login_path, alert: "Iniciá sesión para continuar"
    end
  end

  def current_admin
    @current_admin ||= User.find_by(id: session[:admin_user_id])
  end
  helper_method :current_admin
end
