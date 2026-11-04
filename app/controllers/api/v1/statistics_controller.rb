class Api::V1::StatisticsController < Api::V1::BaseController
  FIRST_YEAR = 2000

  # Estadísticas de un año (`?year=AAAA`, por defecto el actual) o de un mes de ese año
  # (`?month=1..12`, opcional): consumo, ahorro y gasto hormiga mes a mes, consumo por categoría y
  # detalle del gasto hormiga. Cada usuario ve las suyas; el admin, las de todos.
  def show
    year = parse_year
    return if performed?

    month = parse_month
    return if performed?

    render json: StatisticsReport.new(
      year: year, month: month, incomes: visible_incomes, expenses: visible_expenses,
      shopping_items: visible_shopping_list_items
    ).as_json
  end

  private

  def parse_year
    return Date.current.year if params[:year].blank?

    year = Integer(params[:year].to_s, 10, exception: false)
    return year if year && year.between?(FIRST_YEAR, Date.current.year)

    render_error(api_t("invalid_year"), status: :unprocessable_entity, field: "year")
    nil
  end

  def parse_month
    return nil if params[:month].blank?

    month = Integer(params[:month].to_s, 10, exception: false)
    return month if month && month.between?(1, 12)

    render_error(api_t("invalid_month"), status: :unprocessable_entity, field: "month")
    nil
  end
end
