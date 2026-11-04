class Api::V1::CategoriesController < Api::V1::BaseController
  # Las categorías son compartidas por todos los usuarios: solo el admin las crea y las edita.
  before_action :require_admin!, only: %i[create update destroy]
  before_action :set_category, only: %i[update destroy comparison]

  def index
    categories = Category.order(:name)

    render json: categories.map { |category| category_json(category) }
  end

  # Lo estimado (lista de gastos fijos) contra lo real (gastos) de una categoría en un mes
  # (`?period=AAAA-MM`; si falta, el mes en curso). Cualquier usuario la consulta, con sus datos.
  def comparison
    period = params[:period].presence || Date.current.strftime("%Y-%m")
    unless period.match?(CategoryComparison::PERIOD_FORMAT)
      return render_error(api_t("invalid_period"), status: :unprocessable_entity, field: "period")
    end

    render json: CategoryComparison.new(
      category: @category, period: period,
      expenses: visible_expenses, shopping_items: visible_shopping_list_items
    ).as_json
  end

  def create
    category = Category.new(category_params)

    if category.save
      render json: category_json(category), status: :created
    else
      render_record_errors(category)
    end
  end

  def update
    if @category.update(category_params)
      render json: category_json(@category)
    else
      render_record_errors(@category)
    end
  end

  # No se borra una categoría que tiene gastos, compras en cuotas, gastos fijos o subcategorías:
  # se perdería ese historial. Primero hay que mover o borrar eso.
  def destroy
    if category_in_use?(@category)
      render_error(api_t("category_in_use"), status: :unprocessable_entity)
    else
      @category.destroy!
      head :no_content
    end
  end

  private

  def category_in_use?(category)
    category.expenses.exists? ||
      category.installment_purchases.exists? ||
      category.subcategories.exists? ||
      ShoppingListItem.exists?(category_id: category.id)
  end

  def set_category
    @category = Category.find(params[:id])
  end

  def category_params
    params.permit(:name, :parent_id, :tracks_installments)
  end

  def category_json(category)
    {
      id: category.id,
      name: category.name,
      parent_id: category.parent_id,
      tracks_installments: category.tracks_installments
    }
  end
end
