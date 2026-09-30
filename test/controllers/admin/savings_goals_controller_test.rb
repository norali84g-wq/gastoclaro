require "test_helper"

class Admin::SavingsGoalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @familia = FamilyGroup.create!(name: "Familia de prueba")
    @admin = User.create!(user: "admin", password: "password123", admin: true,
                          email: "admin@example.com", family_group: @familia)
    @meta = SavingsGoal.create!(family_group: @familia, name: "Viaje", target_amount: 1000, saved_amount: 400)
  end

  def login
    post "/admin/login", params: { user: "admin", password: "password123" }
  end

  def actualizar(saved_amount)
    patch "/admin/savings_goals/#{@meta.id}", params: { savings_goal: { saved_amount: saved_amount } }
  end

  test "al cruzar el monto objetivo se encola el mail de felicitacion" do
    login

    assert_enqueued_emails 1 do
      actualizar 1000
    end

    assert_redirected_to admin_savings_goals_path
  end

  test "el mail encolado llega al admin logueado con los datos de la meta" do
    login

    perform_enqueued_jobs do
      actualizar 1200
    end

    mail = ActionMailer::Base.deliveries.last
    assert_equal [ "admin@example.com" ], mail.to
    assert_includes mail.subject, "Viaje"
    assert_includes mail.text_part.body.to_s, "$1.200,00"
  end

  test "si la meta sigue sin cumplirse no se manda mail" do
    login

    assert_no_enqueued_emails do
      actualizar 900
    end
  end

  test "si la meta ya estaba cumplida no se vuelve a mandar mail" do
    @meta.update!(saved_amount: 1000)
    login

    assert_no_enqueued_emails do
      actualizar 1500
    end
  end

  test "si el admin no tiene email cargado no se manda mail" do
    @admin.update!(email: nil)
    login

    assert_no_enqueued_emails do
      actualizar 1000
    end

    assert_redirected_to admin_savings_goals_path
  end
end
