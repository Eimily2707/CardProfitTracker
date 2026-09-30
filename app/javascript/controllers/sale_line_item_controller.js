import { Controller } from "@hotwired/stimulus"

// Copies the chosen inventory item's name into the line's description field
// (spec US-5.1 "selezione dinamica dei pezzi presenti in inventario") - the
// description stays editable afterwards.
export default class extends Controller {
  static targets = ["item", "description"]

  fill() {
    const option = this.itemTarget.selectedOptions[0]
    if (!option || !option.dataset.name) return

    this.descriptionTarget.value = option.dataset.name
  }
}
