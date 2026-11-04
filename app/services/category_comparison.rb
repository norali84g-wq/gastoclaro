# Compara lo estimado (lista de gastos fijos) con lo real (gastos) de una categoría en un mes.
# Es el detalle que el back-office muestra al abrir una categoría:
# - si tiene subcategorías, una fila por subcategoría con su estimado y su real;
# - si no, una fila por producto, con cantidades y precios estimados y reales.
class CategoryComparison
  PERIOD_FORMAT = /\A\d{4}-(0[1-9]|1[0-2])\z/

  # `expenses` y `shopping_items` son lo que el usuario puede ver (ya filtrado por la API).
  def initialize(category:, period:, expenses:, shopping_items:)
    @category = category
    @period = period
    @expenses = expenses
    @shopping_items = shopping_items
    @range = Date.strptime("#{period}-01", "%Y-%m-%d").then { |start| start..start.end_of_month }
  end

  def as_json(*)
    subcategories = @category.subcategories.order(:name).to_a
    rows = subcategories.any? ? subcategory_rows(subcategories) : []
    items = subcategories.any? ? [] : item_rows

    {
      category: category_json(@category),
      period: @period,
      planned_total: subcategories.any? ? rows.sum(0.to_d) { |row| row[:planned] } : planned_total(@category),
      real_total: subcategories.any? ? rows.sum(0.to_d) { |row| row[:real] } : real_total(@category),
      subcategories: rows,
      items: items
    }
  end

  # Filas por producto. Los productos se emparejan por nombre, sin importar mayúsculas ni espacios
  # en los extremos. Un producto real que no estaba planificado es "unplanned" (gasto hormiga); uno
  # planificado que no se compró es "not_bought".
  def self.product_rows(planned_items, real_items)
    planned_by_name = planned_items.group_by { |item| normalize(item.name) }
    real_by_name = real_items.group_by { |item| normalize(item.name) }

    (planned_by_name.keys + real_by_name.keys).uniq.map do |key|
      planned = planned_by_name[key] || []
      real = real_by_name[key] || []
      real_quantity = real.sum(&:quantity)
      real_total = real.sum(0.to_d, &:subtotal)

      {
        name: planned.first&.name || real.first&.name,
        planned_quantity: planned.sum(0.to_d) { |item| item.quantity || 0 },
        planned_unit_price: (planned.first&.estimated_unit_price || 0).to_d,
        planned_total: planned.sum(0.to_d, &:subtotal),
        real_quantity: real_quantity,
        real_unit_price: real_quantity > 0 ? real_total / real_quantity : 0.to_d,
        real_total: real_total,
        status: product_status(planned, real)
      }
    end
  end

  def self.product_status(planned, real)
    return "unplanned" if planned.empty? && real.any?
    return "not_bought" if planned.any? && real.empty?

    "bought"
  end

  def self.normalize(name)
    name.to_s.strip.downcase
  end

  private

  def item_rows
    planned = @shopping_items.where(category_id: @category.id, period: @period).to_a
    real = ExpenseItem.where(expense_id: @expenses.where(category_id: @category.id, date: @range).select(:id)).to_a
    self.class.product_rows(planned, real)
  end

  def subcategory_rows(subcategories)
    subcategories.map do |subcategory|
      planned = planned_total(subcategory)
      real = real_total(subcategory)

      { category: category_json(subcategory), planned: planned, real: real,
        over_budget: planned > 0 && real > planned }
    end
  end

  def planned_total(category)
    @shopping_items.where(category_id: category.id, period: @period).to_a.sum(0.to_d, &:subtotal)
  end

  def real_total(category)
    @expenses.where(category_id: category.id, date: @range).sum(:amount)
  end

  def category_json(category)
    { id: category.id, name: category.name }
  end
end
