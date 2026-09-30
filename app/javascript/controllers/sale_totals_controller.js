import { Controller } from "@hotwired/stimulus"

// Live subtotal/charges/net-proceeds preview while editing a sale (spec
// §6.5 US-5.1 "Anteprima: ricavo netto..."). Client-side approximation only
// - the authoritative cent-accurate totals are computed server-side in
// SaleOrder#freeze_totals! at confirm_payment time.
export default class extends Controller {
  static targets = ["unitPrice", "chargeAmount", "chargeKind", "subtotal", "chargesTotal", "total"]

  connect() {
    this.recompute()
  }

  recompute() {
    const subtotal = this.visible(this.unitPriceTargets).reduce((sum, field) => {
      return sum + (parseFloat(field.value.replace(",", ".")) || 0)
    }, 0)

    const chargesTotal = this.visible(this.chargeAmountTargets).reduce((sum, field, index) => {
      const kindField = this.visible(this.chargeKindTargets)[index]
      const direction = kindField?.selectedOptions[0]?.dataset.direction
      const amount = parseFloat(field.value.replace(",", ".")) || 0
      const sign = direction === "expense" ? -1 : 1
      return sum + sign * amount
    }, 0)

    this.subtotalTarget.textContent = subtotal.toFixed(2)
    this.chargesTotalTarget.textContent = chargesTotal.toFixed(2)
    this.totalTarget.textContent = (subtotal + chargesTotal).toFixed(2)
  }

  visible(fields) {
    return fields.filter((field) => !field.closest("[data-nested-form-target='item']")?.hidden)
  }
}
