import { Controller } from "@hotwired/stimulus"

// Live search + filters for the catalog browse page (spec §6.1, US-1.2).
// Debounces the query input and re-fetches whenever a filter dropdown
// changes, rendering results as a card grid.
export default class extends Controller {
  static targets = ["query", "game", "category", "expansion", "results", "empty"]
  static values = { url: String }

  connect() {
    this.debounceTimer = null
    this.fetch()
  }

  disconnect() {
    clearTimeout(this.debounceTimer)
  }

  search() {
    clearTimeout(this.debounceTimer)
    this.debounceTimer = setTimeout(() => this.fetch(), 250)
  }

  filter() {
    this.fetch()
  }

  async fetch() {
    const params = new URLSearchParams()
    const query = this.queryTarget.value.trim()

    if (query.length > 0) params.set("query", query)
    if (this.hasGameTarget && this.gameTarget.value) params.set("ct_game_id", this.gameTarget.value)
    if (this.hasCategoryTarget && this.categoryTarget.value) params.set("ct_category_id", this.categoryTarget.value)
    if (this.hasExpansionTarget && this.expansionTarget.value) params.set("ct_expansion_id", this.expansionTarget.value)

    let response
    try {
      response = await fetch(`${this.urlValue}?${params}`, { headers: { Accept: "application/json" } })
    } catch (error) {
      return
    }

    if (!response.ok) return

    this.render(await response.json())
  }

  render(results) {
    this.resultsTarget.innerHTML = ""
    this.emptyTarget.classList.toggle("hidden", results.length > 0)

    results.forEach((result) => {
      const card = document.createElement("div")
      card.className = "rounded-lg border border-gray-200 bg-white p-3 shadow-sm"
      card.innerHTML = `
        <img src="${result.image_url ?? ""}" alt="" class="mb-2 h-32 w-full rounded object-contain bg-gray-50">
        <p class="truncate text-sm font-medium text-gray-900">${this.escapeHtml(result.name)}</p>
        <p class="truncate text-xs text-gray-500">${this.escapeHtml(result.expansion_name ?? "")}</p>
        <p class="text-xs text-gray-400">${this.escapeHtml(result.collector_number ?? "")} ${this.escapeHtml(result.rarity ?? "")}</p>
      `
      this.resultsTarget.appendChild(card)
    })
  }

  escapeHtml(value) {
    const div = document.createElement("div")
    div.textContent = value ?? ""
    return div.innerHTML
  }
}
