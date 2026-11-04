class Api::V1::DashboardController < Api::V1::BaseController
  MONTHS_HISTORY = 6

  def show
    today = Date.current
    month_start = today.beginning_of_month
    month_end = today.end_of_month

    month_incomes = visible_incomes.where(date: month_start..month_end)
    income = month_incomes.sum(:amount)

    month_expenses = visible_expenses.where(date: month_start..month_end)
    consumption = month_expenses.sum(:amount)

    consumption_by_category = month_expenses
      .joins(:category)
      .group("categories.id", "categories.name")
      .sum(:amount)

    planned_by_category = visible_shopping_list_items
      .where(period: today.strftime("%Y-%m"))
      .includes(:category)
      .group_by { |item| [ item.category.id, item.category.name ] }
      .transform_values { |items| items.sum(&:subtotal) }

    categories = (consumption_by_category.keys + planned_by_category.keys).uniq

    savings = income - consumption

    accumulated = 0
    monthly_savings = (MONTHS_HISTORY - 1).downto(0).map do |i|
      start_date = today.beginning_of_month - i.months
      end_date = start_date.end_of_month

      month_income = visible_incomes.where(date: start_date..end_date).sum(:amount)
      month_consumption = visible_expenses.where(date: start_date..end_date).sum(:amount)

      month_savings = month_income - month_consumption
      accumulated += month_savings

      {
        month: start_date.strftime("%Y-%m"),
        income: month_income,
        consumption: month_consumption,
        savings: month_savings,
        accumulated: accumulated
      }
    end

    render json: {
      period: today.strftime("%Y-%m"),
      income: income,
      consumption: consumption,
      savings: savings,
      savings_goal_percentage: current_user.family_group.savings_percentage,
      incomes: month_incomes.includes(:user).order(:date).map { |i|
        { id: i.id, user: { id: i.user.id, user: i.user.user }, amount: i.amount, date: i.date }
      },
      consumption_by_category: categories.map { |id, name|
        {
          category_id: id,
          category: name,
          total: consumption_by_category.fetch([ id, name ], 0).to_d,
          planned: planned_by_category.fetch([ id, name ], 0).to_d
        }
      },
      monthly_savings: monthly_savings
    }
  end
end
