class Admin::ShoppingListItemsController < Admin::BaseController
  before_action :set_shopping_list_item, only: [ :edit, :update, :destroy ]

  MAX_BATCH_ITEMS = 1000
  DEFAULT_BATCH_ITEMS = 10

  def index
    items = ShoppingListItem.includes(:category, :family_group).order(:period, :name)
    @items_by_category = items.group_by(&:category)
    @top_categories = Category.where(parent_id: nil).includes(:subcategories).order(:name)
  end

  def new
    @shopping_list_item = ShoppingListItem.new
  end

  def create
    @shopping_list_item = ShoppingListItem.new(shopping_list_item_params)
    if @shopping_list_item.save
      redirect_to admin_shopping_list_items_path, notice: "Producto agregado a la lista."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @shopping_list_item.update(shopping_list_item_params)
      redirect_to admin_shopping_list_items_path, notice: "Producto actualizado."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @shopping_list_item.destroy
    redirect_to admin_shopping_list_items_path, notice: "Producto eliminado de la lista."
  end

  def new_batch
    @category = Category.find(params[:category_id])
    @period = params[:period].presence || Date.current.strftime("%Y-%m")
    @rows_count = batch_rows_count
  end

  def create_batch
    category = Category.find(params[:category_id])
    period = params[:period]
    family_group = FamilyGroup.first
    rows = params.permit(items: [ :name, :quantity, :estimated_unit_price ])[:items] || []

    created = 0
    ShoppingListItem.transaction do
      rows.each do |row|
        next if row[:name].blank?
        ShoppingListItem.create!(
          family_group: family_group,
          category: category,
          period: period,
          name: row[:name],
          quantity: row[:quantity],
          estimated_unit_price: row[:estimated_unit_price].presence || 0
        )
        created += 1
      end
    end

    redirect_to admin_shopping_list_items_path, notice: "#{created} producto(s) agregados a #{category.name}."
  end

  private

  def set_shopping_list_item
    @shopping_list_item = ShoppingListItem.find(params[:id])
  end

  def batch_rows_count
    raw = params[:items].presence
    count = raw ? raw.to_i : DEFAULT_BATCH_ITEMS
    count.clamp(1, MAX_BATCH_ITEMS)
  end

  def shopping_list_item_params
    params.require(:shopping_list_item).permit(:family_group_id, :category_id, :name, :period, :quantity, :estimated_unit_price)
  end
end
