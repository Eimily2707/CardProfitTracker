import { Controller } from "@hotwired/stimulus"

// Live subtotal/charges/total preview while editing a purchase (spec §6.2
// US-2.1 "Totali aggiornati dal vivo"). This is a client-side approximation
// for feedback only - the authoritative cent-accurate totals are computed
// server-side in Purchase#freeze_totals! at confirm time.
export default class extends Controller {
  static targets = ["quantity", "unitPrice", "chargeAmount", "subtotal", "chargesTotal", "total"]

  connect() {
    this.recompute()
  }

  recompute() {
    const subtotal = this.visible(this.quantityTargets).reduce((sum, quantityField, index) => {
      const unitPriceField = this.visible(this.unitPriceTargets)[index]
      if (!unitPriceField) return sum

      const quantity = parseInt(quantityField.value, 10) || 0
      const unitPrice = parseFloat(unitPriceField.value.replace(",", ".")) || 0
      return sum + quantity * unitPrice
    }, 0)

    const chargesTotal = this.visible(this.chargeAmountTargets).reduce((sum, field) => {
      return sum + (parseFloat(field.value.replace(",", ".")) || 0)
    }, 0)

    this.subtotalTarget.textContent = subtotal.toFixed(2)
    this.chargesTotalTarget.textContent = chargesTotal.toFixed(2)
    this.totalTarget.textContent = (subtotal + chargesTotal).toFixed(2)
  }

  visible(fields) {
    return fields.filter((field) => !field.closest("[data-nested-form-target='item']")?.hidden)
  }
}
