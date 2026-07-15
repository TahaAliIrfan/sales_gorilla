import { Controller } from "@hotwired/stimulus"

// Searchable customer picker for the deal form. Types into a text box, queries
// /deals/search_customers, and writes the chosen id into a hidden field. Avoids
// a giant unsearchable <select> over thousands of customers.
export default class extends Controller {
  static targets = ["input", "hidden", "results", "clear"]
  static values = { url: String }

  connect() {
    this._debounce = null
    this._toggleClear()
    document.addEventListener("click", this._onOutside)
  }

  disconnect() {
    document.removeEventListener("click", this._onOutside)
  }

  _onOutside = (e) => {
    if (!this.element.contains(e.target)) this._hideResults()
  }

  search() {
    this.hiddenTarget.value = "" // typing invalidates the previous pick
    this._toggleClear()
    const q = this.inputTarget.value.trim()
    clearTimeout(this._debounce)
    if (q.length < 2) { this._hideResults(); return }
    this._debounce = setTimeout(() => this._fetch(q), 200)
  }

  async _fetch(q) {
    try {
      const res = await fetch(`${this.urlValue}?q=${encodeURIComponent(q)}`, {
        credentials: "same-origin", headers: { Accept: "application/json" },
      })
      const data = await res.json().catch(() => ({}))
      this._render(data.customers || [])
    } catch (e) {
      this._hideResults()
    }
  }

  _render(customers) {
    this.resultsTarget.innerHTML = ""
    if (!customers.length) {
      this.resultsTarget.innerHTML = `<div class="px-3 py-2 text-sm text-gray-400">No matches</div>`
    } else {
      customers.forEach((c) => {
        const b = document.createElement("button")
        b.type = "button"
        b.className = "w-full text-left px-3 py-2 hover:bg-emerald-50 text-sm border-b border-gray-50 last:border-0"
        const sub = [c.company, c.email].filter(Boolean).join(" · ")
        b.innerHTML = `<span class="text-gray-900">${this._esc(c.name || "(no name)")}</span>${sub ? `<span class="block text-xs text-gray-400">${this._esc(sub)}</span>` : ""}`
        b.addEventListener("click", () => this._pick(c))
        this.resultsTarget.appendChild(b)
      })
    }
    this._showResults()
  }

  _pick(c) {
    this.hiddenTarget.value = c.id
    this.inputTarget.value = c.name || `Customer #${c.id}`
    this._hideResults()
    this._toggleClear()
  }

  clear() {
    this.hiddenTarget.value = ""
    this.inputTarget.value = ""
    this.inputTarget.focus()
    this._hideResults()
    this._toggleClear()
  }

  _toggleClear() {
    if (this.hasClearTarget) this.clearTarget.classList.toggle("hidden", this.inputTarget.value.trim() === "")
  }

  _showResults() { this.resultsTarget.classList.remove("hidden") }
  _hideResults() { this.resultsTarget.classList.add("hidden") }
  _esc(s) { const d = document.createElement("div"); d.textContent = s == null ? "" : String(s); return d.innerHTML }
}
