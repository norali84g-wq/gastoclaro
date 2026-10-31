family_group = FamilyGroup.find_or_create_by!(name: "Familia Gorosito") do |fg|
  fg.savings_percentage = 10
end

User.find_or_create_by!(user: "admin") do |u|
  u.password = "admin1234"
  u.family_group = family_group
  u.admin = true
end

puts "Admin creado -> usuario: admin / contraseña: admin1234"

# Categorías de ejemplo (las del contrato de la API, api.md).
supermercado = Category.find_or_create_by!(name: "Supermercado")
limpieza = Category.find_or_create_by!(name: "Limpieza")

# Datos de demostración: un usuario de prueba con ingresos y gastos para que el panel muestre algo.
# No es una cuenta real y no se crea en producción. Se pueden volver a correr sin duplicar nada.
unless Rails.env.production?
  demo_family = FamilyGroup.find_or_create_by!(name: "Personal - demo") do |fg|
    fg.savings_percentage = 10
  end

  demo = User.find_or_create_by!(user: "demo") do |u|
    u.email = "demo@example.com"
    u.password = "demo1234"
    u.family_group = demo_family
  end

  today = Date.current
  last_month = today.prev_month

  [ [ today, "Sueldo" ], [ last_month, "Sueldo (mes anterior)" ] ].each do |date, description|
    Income.find_or_create_by!(user: demo, description: description) do |income|
      income.amount = 450_000
      income.date = date
    end
  end

  [
    { date: today, category: supermercado, description: "Compra semanal",
      items: [ [ "Leche", 2, 1800.5 ], [ "Arroz", 1, 9500 ] ] },
    { date: today, category: limpieza, description: "Productos de limpieza", amount: 25_000 },
    { date: last_month, category: supermercado, description: "Compra del mes anterior", amount: 38_000 }
  ].each do |data|
    next if Expense.exists?(user: demo, description: data[:description])

    expense = Expense.new(user: demo, category: data[:category], date: data[:date],
                          description: data[:description], amount: data[:amount])
    data[:items]&.each do |name, quantity, unit_price|
      expense.expense_items.build(name: name, quantity: quantity, unit_price: unit_price)
    end
    expense.save!
  end

  puts "Usuario de demostración -> usuario: demo / contraseña: demo1234"
end
