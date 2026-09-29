import { Controller } from "@hotwired/stimulus"

// Submits the account switcher form as soon as a different workspace is picked.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
