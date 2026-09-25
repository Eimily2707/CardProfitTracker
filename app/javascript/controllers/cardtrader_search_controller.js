import { Controller } from "@hotwired/stimulus"

// Live autocomplete against the local Cardtrader::SearchController#index
// endpoint. Selecting a result fills the hidden fields the unboxing form
// submits (blueprint id, image url, card name, set name) and shows a preview.
export default class extends Controller {
  static targets = [
    "query", "results",
    "blueprintId", "imageUrl", "cardName", "setName",
    "preview", "previewImage", "previewName", "previewSet"
  ]
  static values = { url: String }

  connect() {
    this.debounceTimer = null
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

    const results = await response.json()
    this.renderResults(results)
  }

  renderResults(results) {
    this.resultsTarget.innerHTML = ""

    if (results.length === 0) {
      this.hideResults()
      return
    }

    results.forEach((result) => {
      const item = document.createElement("button")
      item.type = "button"
      item.className = "flex w-full items-center gap-3 px-3 py-2 text-left hover:bg-gray-50"
      item.innerHTML = `
        <img src="${result.image_url ?? ""}" alt="" class="h-10 w-10 flex-none rounded object-contain bg-gray-50">
        <span class="min-w-0">
          <span class="block truncate text-sm font-medium text-gray-900">${this.escapeHtml(result.name)}</span>
          <span class="block truncate text-xs text-gray-500">${this.escapeHtml(result.expansion_name ?? "")}</span>
        </span>
      `
      item.addEventListener("click", () => this.select(result))
      this.resultsTarget.appendChild(item)
    })

    this.resultsTarget.classList.remove("hidden")
  }

  select(result) {
    this.blueprintIdTarget.value = result.cardtrader_id
    this.imageUrlTarget.value = result.image_url ?? ""
    this.cardNameTarget.value = result.name
    this.setNameTarget.value = result.expansion_name ?? ""

    this.previewImageTarget.src = result.image_url ?? ""
    this.previewNameTarget.textContent = result.name
    this.previewSetTarget.textContent = result.expansion_name ?? ""
    this.previewTarget.classList.remove("hidden")

    this.queryTarget.value = result.name
    this.hideResults()
  }

  hideResults() {
    this.resultsTarget.innerHTML = ""
    this.resultsTarget.classList.add("hidden")
  }

  escapeHtml(value) {
    const div = document.createElement("div")
    div.textContent = value ?? ""
    return div.innerHTML
  }
}
