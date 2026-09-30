class Admin::ExpensesController < Admin::BaseController
  before_action :set_expense, only: [:edit, :update, :destroy]

  MAX_ITEMS = 1000
  DEFAULT_ITEMS = 5

  def index
    @expenses = Expense.includes(:user, :vendor, :category, :expense_items).order(date: :desc)
  end

  def new
    @expense = Expense.new(category_id: params[:category_id])

    if params[:category_id].present? && params[:period].present?
      planned_names = ShoppingListItem.where(category_id: params[:category_id], period: params[:period])
                                       .order(:name)
                                       .pluck(:name)
      planned_names.each { |name| @expense.expense_items.build(name: name) }
    end

    blank_rows_count.times { @expense.expense_items.build }
  end

  def create
    @expense = Expense.new(expense_params)
    if @expense.save
      redirect_to admin_expenses_path, notice: "Gasto cargado."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    blank_rows_count.times { @expense.expense_items.build }
  end

  def update
    if @expense.update(expense_params)
      redirect_to admin_expenses_path, notice: "Gasto actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @expense.destroy
    redirect_to admin_expenses_path, notice: "Gasto eliminado."
  end

  private

  def set_expense
    @expense = Expense.find(params[:id])
  end

  def blank_rows_count
    raw = params[:items].presence
    count = raw ? raw.to_i : DEFAULT_ITEMS
    count.clamp(1, MAX_ITEMS)
  end

  def expense_params
    params.require(:expense).permit(
      :user_id, :category_id, :vendor_id, :date, :amount, :is_fixed, :purchase_channel, :receipt_image,
      expense_items_attributes: [:id, :name, :quantity, :unit_price, :unit, :_destroy]
    )
  end
end
