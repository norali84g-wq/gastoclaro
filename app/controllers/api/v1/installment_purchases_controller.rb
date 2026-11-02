class Api::V1::InstallmentPurchasesController < Api::V1::BaseController
  before_action :set_installment_purchase, only: %i[update destroy]

  def index
    purchases = visible_installment_purchases.order(id: :desc)

    render json: purchases.map { |purchase| installment_purchase_json(purchase) }
  end

  def create
    purchase = current_user.family_group.installment_purchases.new(installment_purchase_params)

    if valid_with_vendor?(purchase) && purchase.save
      render json: installment_purchase_json(purchase), status: :created
    else
      render_record_errors(purchase)
    end
  end

  def update
    @installment_purchase.assign_attributes(installment_purchase_params)

    if valid_with_vendor?(@installment_purchase) && @installment_purchase.save
      render json: installment_purchase_json(@installment_purchase)
    else
      render_record_errors(@installment_purchase)
    end
  end

  def destroy
    @installment_purchase.destroy!
    head :no_content
  end

  private

  # Solo se puede tocar una compra visible para el usuario: la de su grupo familiar, o cualquiera si
  # es admin. Si no existe o es de otro grupo, find lanza RecordNotFound y la API responde 404.
  def set_installment_purchase
    @installment_purchase = visible_installment_purchases.find(params[:id])
  end

  def installment_purchase_params
    params.permit(:description, :total_amount, :installments_count, :first_period, :category_id, :vendor_id)
  end

  # Valida todo junto para devolver todos los errores en una sola respuesta. Devuelve true si no hay
  # ningún error (los del modelo ni un vendor_id inexistente).
  def valid_with_vendor?(purchase)
    purchase.validate
    purchase.errors.add(:vendor_id, :not_found) unless vendor_valido?
    purchase.errors.empty?
  end

  # vendor_id tiene que ser un valor simple (número o texto) y existir. Se busca con `id:` para que
  # nunca se interprete como SQL (igual que en los gastos).
  def vendor_valido?
    vendor_id = params[:vendor_id]
    return true if vendor_id.blank?

    (vendor_id.is_a?(String) || vendor_id.is_a?(Integer)) && Vendor.exists?(id: vendor_id)
  end

  # El monto de cada cuota y las cuotas restantes no se guardan: se calculan cada vez.
  # Las cuotas no crean consumo, así que esto no afecta al dashboard.
  def installment_purchase_json(purchase)
    {
      id: purchase.id,
      description: purchase.description,
      total_amount: purchase.total_amount,
      installments_count: purchase.installments_count,
      first_period: purchase.first_period,
      category_id: purchase.category_id,
      vendor_id: purchase.vendor_id,
      installment_amount: purchase.monto_por_cuota,
      remaining_installments: purchase.cuotas_restantes
    }
  end
end
