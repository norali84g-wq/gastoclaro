require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @familia = FamilyGroup.create!(name: "Familia de prueba")
  end

  test "el email es opcional pero si se carga debe tener formato valido" do
    assert User.new(user: "a", password: "password123", family_group: @familia, email: nil).valid?
    assert User.new(user: "b", password: "password123", family_group: @familia, email: "b@example.com").valid?
    assert_not User.new(user: "c", password: "password123", family_group: @familia, email: "no-es-un-mail").valid?
  end

  test "el nombre de usuario se guarda en minusculas" do
    user = User.create!(user: "NicoV", password: "password123", family_group: @familia)

    assert_equal "nicov", user.reload.user
  end

  test "el nombre de usuario se guarda sin espacios al principio ni al final" do
    user = User.create!(user: "  nico  ", password: "password123", family_group: @familia)

    assert_equal "nico", user.reload.user
  end

  test "find_by y where encuentran al usuario aunque se busque con mayusculas o espacios" do
    user = User.create!(user: "demo", password: "password123", family_group: @familia)

    assert_equal user, User.find_by(user: "DEMO")
    assert_equal user, User.find_by(user: " Demo ")
    assert_equal [ user ], User.where(user: "Demo").to_a
  end

  test "no se puede crear Demo si ya existe demo" do
    User.create!(user: "demo", password: "password123", family_group: @familia)
    repetido = User.new(user: "Demo", password: "password123", family_group: @familia)

    assert_not repetido.valid?
    assert repetido.errors.of_kind?(:user, :taken)
  end

  test "la base tiene un indice unico sobre el nombre de usuario" do
    index = ActiveRecord::Base.connection.indexes(:users).find { |i| i.columns == [ "user" ] }

    assert index, "falta el indice sobre users.user"
    assert index.unique, "el indice sobre users.user tiene que ser unico"
  end

  test "la base rechaza dos usuarios con el mismo nombre normalizado aunque se salte la validacion" do
    User.create!(user: "demo", password: "password123", family_group: @familia)
    repetido = User.new(user: "demo", password: "password123", family_group: @familia)

    assert_raises(ActiveRecord::RecordNotUnique) { repetido.save!(validate: false) }
  end
end
