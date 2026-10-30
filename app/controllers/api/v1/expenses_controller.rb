class Api::V1::ExpensesController < Api::V1::BaseController
  # Tope de gastos que devuelve el listado (ver api.md, GET /expenses).
  MAX_INDEX_EXPENSES = 100
  # Campo que se informa cuando ?period no tiene el formato YYYY-MM.
  PERIOD_FIELD = "period".freeze
  PERIOD_FORMAT = /\A\d{4}-(0[1-9]|1[0-2])\z/

  def index
    month = parse_period(params[:period])
    if params[:period].present? && month.nil?
      return render_error(api_t("invalid_period"), status: :unprocessable_entity, field: PERIOD_FIELD)
    end

    expenses = visible_expenses.includes(:category, :user, :expense_items)
    expenses = expenses.where(date: month.all_month) if month
    expenses = expenses.order(date: :desc, id: :desc).limit(MAX_INDEX_EXPENSES)

    render json: expenses.map { |expense| expense_json(expense) }
  end

  def create
    expense = current_user.expenses.new(expense_params)

    # Se valida todo junto para devolver todos los errores en una sola respuesta.
    expense.validate
    expense.errors.add(:vendor_id, :not_found) unless vendor_valido?
    expense.errors.add(:purchase_channel, :invalid) if purchase_channel_invalido?

    if expense.errors.empty? && expense.save
      render json: expense_json(expense), status: :created
    else
      render_record_errors(expense)
    end
  end

  private

  # vendor_id tiene que ser un valor simple (número o texto) y existir. Se busca con
  # `id:` para que nunca se interprete como SQL: `Vendor.exists?(valor)` trata un
  # array como condición SQL cruda (inyección).
  def vendor_valido?
    vendor_id = params[:vendor_id]
    return true if vendor_id.blank?

    (vendor_id.is_a?(String) || vendor_id.is_a?(Integer)) && Vendor.exists?(id: vendor_id)
  end

  # Devuelve el primer día del mes, o nil si el valor no es un texto con formato YYYY-MM.
  def parse_period(value)
    return unless value.is_a?(String) && value.match?(PERIOD_FORMAT)

    Date.strptime(value, "%Y-%m")
  end

  def purchase_channel_invalido?
    params[:purchase_channel].present? && !Expense.purchase_channels.key?(params[:purchase_channel])
  end

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
      user: { id: expense.user_id, user: expense.user.user },
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
