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
      .group("categories.name")
      .sum(:amount)

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
        { id: i.id, user: i.user.user, amount: i.amount, date: i.date }
      },
      consumption_by_category: consumption_by_category.map { |category, total|
        { category: category, total: total }
      },
      monthly_savings: monthly_savings
    }
  end
end
