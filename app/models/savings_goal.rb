class SavingsGoal < ApplicationRecord
  belongs_to :family_group

  validates :name, presence: true
  validates :target_amount, numericality: { greater_than: 0 }

  def progress
    return 0 if target_amount.zero?
    ((saved_amount / target_amount) * 100).round
  end

  # Cuántos meses quedan hasta la fecha límite (mínimo 1, para no dividir por cero
  # ni dar un número negativo si la fecha límite ya pasó o es este mismo mes)
  def meses_restantes
    return 1 if deadline.blank?

    meses = (deadline.year * 12 + deadline.month) - (Date.current.year * 12 + Date.current.month)
    [ meses, 1 ].max
  end

  # Falta ahorrar (monto objetivo menos lo ya ahorrado, nunca negativo)
  def falta_ahorrar
    [ target_amount - saved_amount, 0 ].max
  end

  # Cuánto habría que ahorrar por mes, de acá a la fecha límite, para llegar a la meta
  def monto_mensual_necesario
    (falta_ahorrar / meses_restantes).round(2)
  end

  def cumplida?
    saved_amount >= target_amount
  end
end
