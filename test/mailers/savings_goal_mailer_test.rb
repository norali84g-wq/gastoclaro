require "test_helper"

class SavingsGoalMailerTest < ActionMailer::TestCase
  setup do
    familia = FamilyGroup.new(name: "Familia de prueba")
    @meta = SavingsGoal.new(family_group: familia, name: "Viaje a la costa", target_amount: 150_000, saved_amount: 152_500.5)
    @admin = User.new(user: "admin", email: "admin@example.com")
  end

  test "goal_achieved se envia al email del admin con el nombre de la meta en el asunto" do
    mail = SavingsGoalMailer.goal_achieved(@meta, @admin)

    assert_equal [ "admin@example.com" ], mail.to
    assert_equal [ "from@example.com" ], mail.from
    assert_includes mail.subject, "Viaje a la costa"
  end

  test "goal_achieved muestra el nombre de la meta y el monto alcanzado en texto y HTML" do
    mail = SavingsGoalMailer.goal_achieved(@meta, @admin)

    [ mail.text_part, mail.html_part ].each do |parte|
      assert_includes parte.body.to_s, "Viaje a la costa"
      assert_includes parte.body.to_s, "$152.500,50"
    end
  end
end
