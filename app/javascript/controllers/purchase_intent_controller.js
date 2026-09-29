import { Controller } from "@hotwired/stimulus"

// Shows the "search the sealed product on CardTrader" section only while
// the keep_sealed radio is selected.
export default class extends Controller {
  static targets = ["sealedSection"]

  connect() {
    this.toggle()
  }

  toggle() {
    const selected = this.element.querySelector("input[name$='[intent_type]']:checked")
    this.sealedSectionTarget.hidden = selected?.value !== "keep_sealed"
  }
}
