class Admin::CategoriesController < Admin::BaseController
  before_action :set_category, only: [:show, :edit, :update, :destroy]

  def index
    @categories = Category.where(parent_id: nil).includes(:subcategories).order(:name)
  end

  def show
    @period = params[:period].presence || Date.current.strftime("%Y-%m")
    @start_date = Date.parse("#{@period}-01") rescue Date.current.beginning_of_month
    @end_date = @start_date.end_of_month

    @subcategories = @category.subcategories.order(:name)

    if @subcategories.any?
      @subcategory_rows = @subcategories.map do |sub|
        {
          category: sub,
          estimado: estimado_total(sub, @period),
          real: real_total(sub, @start_date, @end_date)
        }
      end
    else
      @estimado_total = estimado_total(@category, @period)
      @real_total = real_total(@category, @start_date, @end_date)
      @comparison_rows = comparison_rows(@category, @period, @start_date, @end_date)
    end
  end

  def new
    @category = Category.new(parent_id: params[:parent_id])
  end

  def create
    @category = Category.new(category_params)
    if @category.save
      tipo = @category.parent_id.present? ? "Subcategoría creada" : "Categoría creada"

      if params[:commit] == "Guardar y agregar otra"
        redirect_to new_admin_category_path(parent_id: @category.parent_id), notice: tipo
      elsif @category.parent_id.present?
        redirect_to admin_category_path(@category.parent_id), notice: tipo
      else
        redirect_to admin_categories_path, notice: tipo
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @category.update(category_params)
      redirect_to (params[:return_to].presence || admin_categories_path), notice: "Categoría actualizada"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    parent_id = @category.parent_id
    tipo = parent_id.present? ? "Subcategoría" : "Categoría"
    destino_si_falla = params[:return_to].presence || (parent_id.present? ? admin_category_path(parent_id) : admin_categories_path)

    begin
      @category.destroy!
      redirect_to destino_si_falla, notice: "#{tipo} eliminada"
    rescue ActiveRecord::InvalidForeignKey, ActiveRecord::DeleteRestrictionError
      redirect_to destino_si_falla, alert: "No se pudo eliminar \"#{@category.name}\" porque todavía tiene gastos, productos planificados o subcategorías cargadas. Vaciala o movela primero."
    end
  end

  private

  def set_category
    @category = Category.find(params[:id])
  end

  def category_params
    params.require(:category).permit(:name, :parent_id, :tracks_installments)
  end

  def estimado_total(category, period)
    ShoppingListItem.where(category: category, period: period).sum(&:subtotal)
  end

  def real_total(category, start_date, end_date)
    Expense.where(category: category, date: start_date..end_date).sum(:amount)
  end

  def comparison_rows(category, period, start_date, end_date)
    planned = ShoppingListItem.where(category: category, period: period)
    planned_by_name = planned.group_by { |item| item.name.strip.downcase }

    real_items = ExpenseItem.joins(:expense)
                             .where(expenses: { category_id: category.id, date: start_date..end_date })
    real_by_name = real_items.group_by { |item| item.name.strip.downcase }

    all_keys = (planned_by_name.keys + real_by_name.keys).uniq

    all_keys.map do |key|
      planned_rows = planned_by_name[key] || []
      real_rows = real_by_name[key] || []

      planned_qty = planned_rows.sum { |item| item.quantity || 0 }
      planned_price = planned_rows.first&.estimated_unit_price || 0
      planned_total = planned_rows.sum(&:subtotal)

      real_qty = real_rows.sum(&:quantity)
      real_total = real_rows.sum(&:subtotal)
      real_price = real_qty > 0 ? (real_total / real_qty) : 0

      {
        name: planned_rows.first&.name || real_rows.first&.name,
        planned_qty: planned_qty,
        planned_price: planned_price,
        planned_total: planned_total,
        real_qty: real_qty,
        real_price: real_price,
        real_total: real_total,
        real_items: real_rows,
        hormiga: planned_rows.empty? && real_rows.any?,
        no_comprado: planned_rows.any? && real_rows.empty?
      }
    end
  end
end
