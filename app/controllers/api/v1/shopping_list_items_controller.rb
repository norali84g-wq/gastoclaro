class Api::V1::ShoppingListItemsController < Api::V1::BaseController
  before_action :set_shopping_list_item, only: %i[update destroy]

  def index
    items = visible_shopping_list_items.includes(:category).order(:period, :name, :id)
    items = items.where(period: params[:period]) if params[:period].present?

    render json: items.map { |item| shopping_list_item_json(item) }
  end

  def create
    item = current_user.family_group.shopping_list_items.new(shopping_list_item_params)

    if item.save
      render json: shopping_list_item_json(item), status: :created
    else
      render_record_errors(item)
    end
  end

  def update
    if @shopping_list_item.update(shopping_list_item_params)
      render json: shopping_list_item_json(@shopping_list_item)
    else
      render_record_errors(@shopping_list_item)
    end
  end

  def destroy
    @shopping_list_item.destroy!
    head :no_content
  end

  private

  # Solo se puede tocar un ítem visible para el usuario: el de su grupo familiar, o cualquiera si es
  # admin. Si no existe o es de otro grupo, find lanza RecordNotFound y la API responde 404.
  def set_shopping_list_item
    @shopping_list_item = visible_shopping_list_items.find(params[:id])
  end

  def shopping_list_item_params
    params.permit(:name, :period, :quantity, :estimated_unit_price, :category_id)
  end

  # El subtotal no se guarda: se calcula cada vez (cantidad × precio unitario estimado).
  def shopping_list_item_json(item)
    {
      id: item.id,
      name: item.name,
      period: item.period,
      quantity: item.quantity,
      estimated_unit_price: item.estimated_unit_price,
      subtotal: item.subtotal,
      category: item.category && { id: item.category.id, name: item.category.name }
    }
  end
end
