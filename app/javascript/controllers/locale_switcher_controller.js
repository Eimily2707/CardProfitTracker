import { Controller } from "@hotwired/stimulus"

// Submits the locale form as soon as a different language is picked
// (mirrors account_switcher_controller).
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
