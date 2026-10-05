# spec §2.4: PaperTrail's field-level history, surfaced for the account's
# admins/owners. A single generic endpoint rather than one per model,
# since it's the same "record type + id -> its Versions" lookup every
# time. Tenant ownership is checked by hand (record_account_id) since a
# PaperTrail::Version has no account_id of its own to scope by.
class AuditLogsController < ApplicationController
  # A Hash, not constantize(params[:type]) - keeps this a closed allowlist of
  # actual Class objects rather than reflection over arbitrary user input.
  AUDITABLE_TYPES = {
    "Purchase" => Purchase, "PurchaseLine" => PurchaseLine, "PurchaseCharge" => PurchaseCharge,
    "InventoryItem" => InventoryItem, "SaleOrder" => SaleOrder, "SaleLine" => SaleLine, "SaleCharge" => SaleCharge,
    "Expense" => Expense
  }.freeze

  def show
    unless Current.membership&.admin? || Current.membership&.owner?
      redirect_to root_path, alert: t("pundit.not_authorized")
      return
    end

    @record = find_record
    if @record.nil?
      redirect_to root_path, alert: t(".not_found")
      return
    end

    @versions = @record.versions.order(created_at: :desc)
  end

  private

  def find_record
    klass = AUDITABLE_TYPES[params[:type]]
    return nil unless klass

    record = klass.find_by(id: params[:id])
    record if record && record_account_id(record) == Current.account.id
  end

  def record_account_id(record)
    case record
    when PurchaseLine, PurchaseCharge then record.purchase.account_id
    when SaleLine, SaleCharge then record.sale_order.account_id
    else record.account_id
    end
  end
end
