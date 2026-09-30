# Preview all emails at http://localhost:3000/rails/mailers/savings_goal_mailer
class SavingsGoalMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/savings_goal_mailer/goal_achieved
  def goal_achieved
    familia = FamilyGroup.new(name: "Familia de ejemplo")
    meta = SavingsGoal.new(family_group: familia, name: "Viaje a la costa", target_amount: 150_000, saved_amount: 152_500.5)
    admin = User.new(user: "admin", email: "admin@example.com")

    SavingsGoalMailer.goal_achieved(meta, admin)
  end
end
