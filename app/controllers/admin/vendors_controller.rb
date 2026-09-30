class Admin::VendorsController < Admin::BaseController
  before_action :set_vendor, only: [:edit, :update, :destroy]

  def index
    @vendors = Vendor.order(:name)
  end

  def new
    @vendor = Vendor.new
  end

  def create
    @vendor = Vendor.new(vendor_params)
    if @vendor.save
      redirect_to admin_vendors_path, notice: "Comercio creado"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @vendor.update(vendor_params)
      redirect_to admin_vendors_path, notice: "Comercio actualizado"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @vendor.destroy
    redirect_to admin_vendors_path, notice: "Comercio eliminado"
  end

  private

  def set_vendor
    @vendor = Vendor.find(params[:id])
  end

  def vendor_params
    params.require(:vendor).permit(:name, :category, :online_purchase)
  end
end
