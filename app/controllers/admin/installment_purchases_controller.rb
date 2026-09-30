class Admin::InstallmentPurchasesController < Admin::BaseController
  before_action :set_installment_purchase, only: [:edit, :update, :destroy]

  def index
    @category = Category.find(params[:category_id])
    @installment_purchases = @category.installment_purchases.order(first_period: :desc)
  end

  def new
    @installment_purchase = InstallmentPurchase.new(category_id: params[:category_id])
  end

  def create
    @installment_purchase = current_admin.family_group.installment_purchases.new(installment_purchase_params)

    if @installment_purchase.save
      redirect_to admin_category_path(@installment_purchase.category), notice: "Compra en cuotas cargada"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @installment_purchase.update(installment_purchase_params)
      redirect_to admin_category_path(@installment_purchase.category), notice: "Compra en cuotas actualizada"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    categoria = @installment_purchase.category
    @installment_purchase.destroy
    redirect_to admin_category_path(categoria), notice: "Compra en cuotas eliminada"
  end

  private

  def set_installment_purchase
    @installment_purchase = current_admin.family_group.installment_purchases.find(params[:id])
  end

  def installment_purchase_params
    params.require(:installment_purchase).permit(:category_id, :vendor_id, :description, :total_amount, :installments_count, :first_period)
  end
end
