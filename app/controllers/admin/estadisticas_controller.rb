class Admin::EstadisticasController < Admin::BaseController
  MESES_ES = %w[enero febrero marzo abril mayo junio julio agosto
                septiembre octubre noviembre diciembre]

  def show
    family_group = current_admin.family_group

    @anios_disponibles = anios_disponibles(family_group)
    @anio = (params[:anio].presence || Date.current.year).to_i
    @mes = params[:mes].presence
    @meses_es = MESES_ES

    meses_del_anio = meses_del_anio(@anio)
    meses_en_rango = meses_en_rango(@mes, meses_del_anio)

    @periodo_label = periodo_label(@anio, @mes)

    ranking_consumo, ranking_ahorro, ranking_hormiga, consumo_mensual =
      datos_mensuales(family_group, meses_del_anio)

    @ranking_consumo = ranking_consumo
    @ranking_ahorro = ranking_ahorro
    @ranking_hormiga = ranking_hormiga
    @consumo_mensual = consumo_mensual

    @gasto_por_categoria = consumo_por_categoria(family_group, meses_en_rango)
    @hormiga_total, @hormiga_por_comercio, @hormiga_items = gastos_hormiga(family_group, meses_en_rango)
  end

  private

  def anios_disponibles(family_group)
    fecha_ingreso = Income.joins(:user).where(users: { family_group_id: family_group.id }).minimum(:date)
    fecha_gasto = Expense.where(family_group_id: family_group.id).minimum(:date)
    primer_anio = [ fecha_ingreso, fecha_gasto ].compact.min&.year || Date.current.year
    (primer_anio..Date.current.year).to_a.reverse
  end

  def meses_del_anio(anio)
    ultimo_mes = anio == Date.current.year ? Date.current.month : 12
    (1..ultimo_mes).map { |m| Date.new(anio, m, 1) }
  end

  def meses_en_rango(mes, meses_del_anio)
    return meses_del_anio if mes.blank?
    meses_del_anio.select { |m| m.month == mes.to_i }
  end

  def periodo_label(anio, mes)
    return "Año #{anio}" if mes.blank?
    "#{MESES_ES[mes.to_i - 1].capitalize} #{anio}"
  end

  def categorias_hoja
    Category.where.missing(:subcategories)
  end

  def datos_mensuales(family_group, meses_del_anio)
    filas = meses_del_anio.map do |mes|
      fecha_inicio = mes.beginning_of_month
      fecha_fin = mes.end_of_month

      ingreso = Income.joins(:user)
                       .where(users: { family_group_id: family_group.id })
                       .where(date: fecha_inicio..fecha_fin)
                       .sum(:amount)

      consumo = Expense.where(family_group_id: family_group.id, date: fecha_inicio..fecha_fin).sum(:amount)
      ahorro = ingreso - consumo
      hormiga_del_mes, = gastos_hormiga(family_group, [ mes ])

      { mes: mes, consumo: consumo, ahorro: ahorro, hormiga: hormiga_del_mes }
    end

    ranking_consumo = filas.sort_by { |f| -f[:consumo] }
    ranking_ahorro = filas.sort_by { |f| -f[:ahorro] }
    ranking_hormiga = filas.sort_by { |f| -f[:hormiga] }

    [ ranking_consumo, ranking_ahorro, ranking_hormiga, filas ]
  end

  def consumo_por_categoria(family_group, meses_en_rango)
    periodos = meses_en_rango.map { |m| m.strftime("%Y-%m") }
    return [] if meses_en_rango.empty?

    fecha_inicio = meses_en_rango.first.beginning_of_month
    fecha_fin = meses_en_rango.last.end_of_month

    total_periodo = Expense.where(family_group_id: family_group.id, date: fecha_inicio..fecha_fin).sum(:amount)

    filas_por_padre = {}

    categorias_hoja.each do |categoria|
      real = Expense.where(family_group_id: family_group.id, category_id: categoria.id, date: fecha_inicio..fecha_fin).sum(:amount)
      estimado = ShoppingListItem.where(category: categoria, period: periodos).sum(&:subtotal)
      sobre_presupuesto = estimado > 0 && real > estimado

      padre = categoria.parent || categoria
      filas_por_padre[padre] ||= { categoria: padre, total: 0, subcategorias: [] }
      filas_por_padre[padre][:total] += real

      if categoria.parent
        filas_por_padre[padre][:subcategorias] << {
          categoria: categoria, real: real, estimado: estimado, sobre_presupuesto: sobre_presupuesto
        }
      end
    end

    filas_por_padre.values.each do |fila|
      fila[:porcentaje] = total_periodo > 0 ? (fila[:total] * 100.0 / total_periodo).round(1) : 0
      fila[:subcategorias].sort_by! { |sub| -sub[:real] }
      fila[:subcategorias].each do |sub|
        sub[:porcentaje] = total_periodo > 0 ? (sub[:real] * 100.0 / total_periodo).round(1) : 0
      end
    end

    filas_por_padre.values.sort_by { |fila| -fila[:total] }
  end

  def gastos_hormiga(family_group, meses_en_rango)
    items_hormiga = []

    categorias_hoja.each do |categoria|
      meses_en_rango.each do |mes|
        period = mes.strftime("%Y-%m")
        nombres_planificados = ShoppingListItem.where(category: categoria, period: period)
                                                .pluck(:name).map { |n| n.strip.downcase }

        items_reales = ExpenseItem.joins(:expense)
                                   .includes(expense: :vendor)
                                   .where(expenses: {
                                     category_id: categoria.id,
                                     family_group_id: family_group.id,
                                     date: mes.beginning_of_month..mes.end_of_month
                                   })

        items_reales.each do |item|
          next if nombres_planificados.include?(item.name.strip.downcase)
          items_hormiga << item
        end
      end
    end

    total = items_hormiga.sum(&:subtotal)
    por_comercio = items_hormiga.group_by { |item| item.expense.vendor&.name || "Sin comercio especificado" }
                                 .transform_values { |items| items.sum(&:subtotal) }
                                 .sort_by { |_comercio, total| -total }

    [ total, por_comercio, items_hormiga ]
  end
end
