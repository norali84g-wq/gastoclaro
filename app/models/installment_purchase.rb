class InstallmentPurchase < ApplicationRecord
  belongs_to :family_group
  belongs_to :category
  belongs_to :vendor, optional: true

  validates :description, presence: true
  validates :total_amount, numericality: { greater_than: 0 }
  validates :installments_count,
            numericality: { only_integer: true, greater_than_or_equal_to: 1, less_than_or_equal_to: 48 }
  validates :first_period, presence: true, format: { with: /\A\d{4}-\d{2}\z/, message: "debe tener formato AAAA-MM" }

  # Monto de cada cuota (redondeado a 2 decimales)
  def monto_por_cuota
    (total_amount / installments_count).round(2)
  end

  # Lista de todos los períodos ("2026-09", "2026-10", ...) que cubre esta compra
  def periodos
    inicio = Date.strptime(first_period, "%Y-%m")
    (0...installments_count).map { |i| (inicio + i.months).strftime("%Y-%m") }
  end

  # Cuántas cuotas ya se "consumieron" hasta un período dado (por defecto, el mes actual)
  def cuotas_pagadas(hasta_period = Date.current.strftime("%Y-%m"))
    periodos.count { |p| p <= hasta_period }
  end

  # Cuántas cuotas quedan pendientes
  def cuotas_restantes(hasta_period = Date.current.strftime("%Y-%m"))
    [installments_count - cuotas_pagadas(hasta_period), 0].max
  end

  # ¿Ya se terminó de pagar?
  def finalizada?(hasta_period = Date.current.strftime("%Y-%m"))
    cuotas_restantes(hasta_period).zero?
  end
end
