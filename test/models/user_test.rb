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
end
