class Admin::SavingsGoalsController < Admin::BaseController
  before_action :set_savings_goal, only: [ :edit, :update, :destroy ]

  def index
    @savings_goals = current_admin.family_group.savings_goals.order(:deadline)
  end

  def new
    @savings_goal = SavingsGoal.new
  end

  def create
    @savings_goal = current_admin.family_group.savings_goals.new(savings_goal_params)

    if @savings_goal.save
      redirect_to admin_savings_goals_path, notice: "Meta de ahorro creada"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    estaba_cumplida = @savings_goal.cumplida?

    if @savings_goal.update(savings_goal_params)
      notify_goal_achieved if !estaba_cumplida && @savings_goal.cumplida?
      redirect_to admin_savings_goals_path, notice: "Meta de ahorro actualizada"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @savings_goal.destroy
    redirect_to admin_savings_goals_path, notice: "Meta de ahorro eliminada"
  end

  private

  # Mail de felicitación al admin logueado; se encola para no demorar la respuesta.
  # Si el admin no tiene email cargado, no se manda nada.
  def notify_goal_achieved
    return if current_admin.email.blank?

    SavingsGoalMailer.goal_achieved(@savings_goal, current_admin).deliver_later
  end

  def set_savings_goal
    @savings_goal = current_admin.family_group.savings_goals.find(params[:id])
  end

  def savings_goal_params
    params.require(:savings_goal).permit(:name, :target_amount, :saved_amount, :deadline)
  end
end
