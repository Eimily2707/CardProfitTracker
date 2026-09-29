import { Controller } from "@hotwired/stimulus"

// Generic add/remove for a Rails accepts_nested_attributes_for collection
// (spec §6.2 US-2.1 "aggiunta/rimozione dinamica"). One instance per
// collection (purchase_lines, purchase_charges, ...): each wrapping element
// carries its own template/container pair.
export default class extends Controller {
  static targets = ["container", "template", "item"]

  add(event) {
    event.preventDefault()

    const newIndex = new Date().getTime()
    const html = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, newIndex)
    this.containerTarget.insertAdjacentHTML("beforeend", html)
  }

  remove(event) {
    event.preventDefault()

    const item = event.target.closest("[data-nested-form-target='item']")
    const destroyField = item.querySelector("input[name*='_destroy']")

    if (destroyField) {
      destroyField.value = "1"
      item.hidden = true
    } else {
      item.remove()
    }
  }
}
