import { Controller } from "@hotwired/stimulus"

// Per-row blueprint autocomplete on a purchase line (spec §6.2 US-2.1
// "integrazione dell'autocomplete... per la selezione rapida delle
// carte"), against the catalog search endpoint built in Tranche 2. Picking
// a result fills the row's hidden blueprint id and snapshots its
// description/expansion/kind; the description stays editable afterwards
// ("blueprint o testo libero"). ArrowUp/ArrowDown/Enter/Escape (UX polish
// tranche) let the whole thing be driven from the keyboard, never touching
// the mouse.
export default class extends Controller {
  static targets = ["query", "results", "blueprintId", "description", "expansionName", "kind"]
  static values = { url: String }

  connect() {
    this.debounceTimer = null
    this.results = []
    this.activeIndex = -1
  }

  disconnect() {
    clearTimeout(this.debounceTimer)
  }

  search() {
    clearTimeout(this.debounceTimer)
    const query = this.queryTarget.value.trim()

    if (query.length < 2) {
      this.hideResults()
      return
    }

    this.debounceTimer = setTimeout(() => this.performSearch(query), 250)
  }

  async performSearch(query) {
    const url = `${this.urlValue}?query=${encodeURIComponent(query)}`

    let response
    try {
      response = await fetch(url, { headers: { Accept: "application/json" } })
    } catch (error) {
      return
    }

    if (!response.ok) return

    this.renderResults(await response.json())
  }

  renderResults(results) {
    this.results = results
    this.activeIndex = -1
    this.resultsTarget.innerHTML = ""

    if (results.length === 0) {
      this.hideResults()
      return
    }

    results.forEach((result, index) => {
      const item = document.createElement("button")
      item.type = "button"
      item.setAttribute("role", "option")
      item.dataset.index = index
      item.className = "flex w-full items-center gap-2 px-3 py-2 text-left text-sm hover:bg-gray-50"
      item.innerHTML = `
        <span class="min-w-0">
          <span class="block truncate font-medium text-gray-900">${this.escapeHtml(result.name)}</span>
          <span class="block truncate text-xs text-gray-500">${this.escapeHtml(result.expansion_name ?? "")}</span>
        </span>
      `
      item.addEventListener("mouseenter", () => this.setActive(index))
      item.addEventListener("click", () => this.select(result))
      this.resultsTarget.appendChild(item)
    })

    this.resultsTarget.classList.remove("hidden")
  }

  navigate(event) {
    if (this.resultsTarget.classList.contains("hidden") || this.results.length === 0) return

    if (event.key === "ArrowDown") {
      event.preventDefault()
      this.setActive((this.activeIndex + 1) % this.results.length)
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this.setActive((this.activeIndex - 1 + this.results.length) % this.results.length)
    } else if (event.key === "Enter") {
      if (this.activeIndex >= 0) {
        event.preventDefault()
        this.select(this.results[this.activeIndex])
      }
    } else if (event.key === "Escape") {
      this.hideResults()
    }
  }

  setActive(index) {
    const buttons = this.resultsTarget.querySelectorAll("[role='option']")
    buttons.forEach((button) => button.classList.remove("bg-gray-50"))

    this.activeIndex = index
    const active = buttons[index]
    if (active) {
      active.classList.add("bg-gray-50")
      active.scrollIntoView({ block: "nearest" })
    }
  }

  select(result) {
    this.blueprintIdTarget.value = result.id
    this.descriptionTarget.value = result.name
    if (this.hasExpansionNameTarget) this.expansionNameTarget.value = result.expansion_name ?? ""
    if (this.hasKindTarget) this.kindTarget.value = "single"

    this.queryTarget.value = result.name
    this.hideResults()
  }

  hideResults() {
    this.results = []
    this.activeIndex = -1
    this.resultsTarget.innerHTML = ""
    this.resultsTarget.classList.add("hidden")
  }

  escapeHtml(value) {
    const div = document.createElement("div")
    div.textContent = value ?? ""
    return div.innerHTML
  }
}
