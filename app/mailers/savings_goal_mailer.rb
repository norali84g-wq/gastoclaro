class SavingsGoalMailer < ApplicationMailer
  # Felicita a un administrador porque una meta de ahorro llegó a su monto objetivo.
  def goal_achieved(savings_goal, recipient)
    @savings_goal = savings_goal
    @recipient = recipient

    mail to: recipient.email, subject: "¡Cumpliste tu meta \"#{savings_goal.name}\"!"
  end
end
