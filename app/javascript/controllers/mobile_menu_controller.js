import { Controller } from "@hotwired/stimulus"

// Hamburger toggle for the header nav below the sm breakpoint (spec §12
// "Responsive... larghezza 375 px"). Closes on Escape or when a link
// inside the panel is activated (Turbo navigates away anyway).
export default class extends Controller {
  static targets = ["panel"]

  toggle() {
    this.panelTarget.hidden = !this.panelTarget.hidden
  }

  close() {
    this.panelTarget.hidden = true
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.close()
  }
}
