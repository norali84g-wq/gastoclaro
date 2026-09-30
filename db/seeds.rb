family_group = FamilyGroup.find_or_create_by!(name: "Familia Gorosito") do |fg|
  fg.savings_percentage = 10
end

User.find_or_create_by!(user: "admin") do |u|
  u.password = "admin1234"
  u.family_group = family_group
  u.admin = true
end

puts "Admin creado -> usuario: admin / contraseña: admin1234"
