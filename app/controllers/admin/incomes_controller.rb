class Admin::IncomesController < Admin::BaseController
  before_action :set_income, only: [ :edit, :update, :destroy ]

  def index
    @incomes = Income.joins(:user)
                      .where(users: { family_group_id: current_admin.family_group_id })
                      .order(date: :desc)
  end

  def new
    @income = Income.new
  end

  def create
    @income = current_admin.incomes.new(income_params)
    if @income.save
      redirect_to admin_incomes_path, notice: "Ingreso cargado correctamente"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @income.update(income_params)
      redirect_to admin_incomes_path, notice: "Ingreso actualizado"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @income.destroy
    redirect_to admin_incomes_path, notice: "Ingreso eliminado"
  end

  private

  def set_income
    @income = Income.joins(:user)
                     .where(users: { family_group_id: current_admin.family_group_id })
                     .find(params[:id])
  end

  def income_params
    params.require(:income).permit(:description, :amount, :date)
  end
end
