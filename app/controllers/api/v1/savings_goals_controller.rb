class Api::V1::SavingsGoalsController < Api::V1::BaseController
  before_action :set_savings_goal, only: %i[update destroy]

  def index
    goals = visible_savings_goals.order(id: :desc)

    render json: goals.map { |goal| savings_goal_json(goal) }
  end

  def create
    goal = current_user.family_group.savings_goals.new(savings_goal_params)

    if goal.save
      render json: savings_goal_json(goal), status: :created
    else
      render_record_errors(goal)
    end
  end

  def update
    if @savings_goal.update(savings_goal_params)
      render json: savings_goal_json(@savings_goal)
    else
      render_record_errors(@savings_goal)
    end
  end

  def destroy
    @savings_goal.destroy!
    head :no_content
  end

  private

  # Solo se puede tocar una meta visible para el usuario: la de su grupo familiar, o cualquiera si
  # es admin. Si no existe o es de otro grupo, find lanza RecordNotFound y la API responde 404.
  def set_savings_goal
    @savings_goal = visible_savings_goals.find(params[:id])
  end

  def savings_goal_params
    params.permit(:name, :target_amount, :saved_amount, :deadline)
  end

  # El progreso no se guarda: se calcula cada vez (monto ahorrado / monto objetivo).
  def savings_goal_json(goal)
    {
      id: goal.id,
      name: goal.name,
      target_amount: goal.target_amount,
      saved_amount: goal.saved_amount,
      deadline: goal.deadline,
      progress_percentage: goal.progress
    }
  end
end
