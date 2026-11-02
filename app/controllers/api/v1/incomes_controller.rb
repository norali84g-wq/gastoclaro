class Api::V1::IncomesController < Api::V1::BaseController
  before_action :set_income, only: %i[update destroy]

  def index
    incomes = visible_incomes.includes(:user).order(date: :desc, id: :desc)

    render json: incomes.map { |income| income_json(income) }
  end

  def create
    income = current_user.incomes.new(income_params)

    if income.save
      render json: income_json(income), status: :created
    else
      render_record_errors(income)
    end
  end

  def update
    if @income.update(income_params)
      render json: income_json(@income)
    else
      render_record_errors(@income)
    end
  end

  def destroy
    @income.destroy!
    head :no_content
  end

  private

  # Solo se puede tocar un ingreso visible para el usuario: el propio, o cualquiera si es admin.
  # Si no existe o es de otro usuario, find lanza RecordNotFound y la API responde 404.
  def set_income
    @income = visible_incomes.find(params[:id])
  end

  def income_params
    params.permit(:amount, :date)
  end

  def income_json(income)
    {
      id: income.id,
      amount: income.amount,
      date: income.date,
      user: { id: income.user_id, user: income.user.user }
    }
  end
end
