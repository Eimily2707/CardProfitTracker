import { Controller } from "@hotwired/stimulus"

// Auto-dismissing flash toast. Each flash message gets its own instance
// (shared/_toasts partial, rendered once in the layout) rather than the
// static inline <p> every view used to render by hand.
export default class extends Controller {
  static values = { timeout: { type: Number, default: 5000 } }

  connect() {
    this.timer = setTimeout(() => this.dismiss(), this.timeoutValue)
  }

  disconnect() {
    clearTimeout(this.timer)
  }

  dismiss() {
    clearTimeout(this.timer)
    this.element.classList.add("opacity-0", "translate-y-1")
    this.element.addEventListener("transitionend", () => this.element.remove(), { once: true })
  }
}
