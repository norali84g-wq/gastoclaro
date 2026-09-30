require "test_helper"

class ExpenseTest < ActiveSupport::TestCase
  setup do
    @family_group = FamilyGroup.create!(name: "Familia de prueba")
    @user = User.create!(user: "tester", password: "password123", family_group: @family_group)
    @category = Category.create!(name: "Supermercado")
  end

  test "el amount se calcula como la suma de cantidad por precio de los items" do
    expense = Expense.new(user: @user, category: @category, date: Date.today, amount: 999)
    expense.expense_items.build(name: "Leche", quantity: 2, unit_price: 100)
    expense.expense_items.build(name: "Pan", quantity: 1, unit_price: 50)

    assert expense.valid?
    assert_equal 250, expense.amount
  end

  test "sin items se respeta el amount cargado a mano" do
    expense = Expense.new(user: @user, category: @category, date: Date.today, amount: 500)

    assert expense.valid?
    assert_equal 500, expense.amount
  end

  test "sin items un amount de 0, negativo o vacio es invalido" do
    [ 0, -5, nil ].each do |monto|
      expense = Expense.new(user: @user, category: @category, date: Date.today, amount: monto)

      assert_not expense.valid?, "amount #{monto.inspect} deberia ser invalido"
      assert expense.errors.key?(:amount)
    end
  end

  test "sin items un amount positivo es valido" do
    expense = Expense.new(user: @user, category: @category, date: Date.today, amount: 100)

    assert expense.valid?
  end

  test "la fecha es obligatoria" do
    expense = Expense.new(user: @user, category: @category, date: nil, amount: 100)

    assert_not expense.valid?
    assert expense.errors.key?(:date)
  end

  test "si no se indica family_group se toma el del usuario" do
    expense = Expense.new(user: @user, category: @category, date: Date.today, amount: 100)

    assert expense.valid?
    assert_equal @user.family_group_id, expense.family_group_id
  end

  test "al destruir el gasto se destruyen sus items" do
    expense = Expense.new(user: @user, category: @category, date: Date.today)
    expense.expense_items.build(name: "Leche", quantity: 2, unit_price: 100)
    expense.expense_items.build(name: "Pan", quantity: 1, unit_price: 50)
    expense.save!

    assert_difference "ExpenseItem.count", -2 do
      expense.destroy
    end
  end
end
