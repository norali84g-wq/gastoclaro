class Api::V1::IncomesController < Api::V1::BaseController
  def create
    income = current_user.incomes.new(income_params)

    if income.save
      render json: { id: income.id, amount: income.amount, date: income.date }, status: :created
    else
      render_record_errors(income)
    end
  end

  private

  def income_params
    params.permit(:amount, :date)
  end
end
