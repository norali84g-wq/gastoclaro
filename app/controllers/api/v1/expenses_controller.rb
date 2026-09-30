class Api::V1::ExpensesController < Api::V1::BaseController
  def index
    expenses = current_user.family_group.expenses
                           .includes(:category, :expense_items)
                           .order(date: :desc, id: :desc)

    render json: expenses.map { |expense| expense_json(expense) }
  end

  def create
    expense = current_user.expenses.new(expense_params)

    if params[:vendor_id].present? && !Vendor.exists?(params[:vendor_id])
      expense.errors.add(:vendor_id, "no existe")
    end

    if params[:purchase_channel].present? && !Expense.purchase_channels.key?(params[:purchase_channel])
      expense.errors.add(:purchase_channel, "no es válido")
    end

    if expense.errors.empty? && expense.save
      render json: expense_json(expense), status: :created
    else
      render json: { errors: expense.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  # purchase_channel se saca de los params permitidos hasta validarlo, porque un valor
  # fuera del enum haría fallar la asignación con un error 500 en vez de un 422.
  def expense_params
    permitted = params.permit(
      :amount, :date, :description, :category_id, :vendor_id, :is_fixed, :purchase_channel,
      expense_items_attributes: [ :name, :quantity, :unit, :unit_price ]
    )
    permitted.delete(:purchase_channel) unless Expense.purchase_channels.key?(permitted[:purchase_channel])
    permitted
  end

  def expense_json(expense)
    {
      id: expense.id,
      amount: expense.amount,
      date: expense.date,
      description: expense.description,
      is_fixed: expense.is_fixed,
      purchase_channel: expense.purchase_channel,
      user_id: expense.user_id,
      vendor_id: expense.vendor_id,
      category: { id: expense.category_id, name: expense.category.name },
      expense_items: expense.expense_items.map { |item|
        {
          id: item.id,
          name: item.name,
          quantity: item.quantity,
          unit: item.unit,
          unit_price: item.unit_price,
          subtotal: item.subtotal
        }
      }
    }
  end
end
