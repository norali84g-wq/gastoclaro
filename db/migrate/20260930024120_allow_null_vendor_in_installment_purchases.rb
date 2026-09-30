class AllowNullVendorInInstallmentPurchases < ActiveRecord::Migration[8.1]
  def change
    change_column_null :installment_purchases, :vendor_id, true
  end
end
