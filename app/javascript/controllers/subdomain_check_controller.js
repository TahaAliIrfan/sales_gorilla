import { Controller } from "@hotwired/stimulus"

// Hits the check_subdomain JSON endpoint as the user types on the new-org form
// and surfaces the result inline.
export default class extends Controller {
  static targets = ["input", "status"]
  static values = { url: String }

  onInput() {
    clearTimeout(this.timer)
    const value = this.inputTarget.value.trim().toLowerCase()
    if (!value) {
      this.#setStatus("", "neutral")
      return
    }
    this.#setStatus("Checking…", "neutral")
    this.timer = setTimeout(() => this.#fetch(value), 250)
  }

  async #fetch(value) {
    const url = `${this.urlValue}?subdomain=${encodeURIComponent(value)}`
    try {
      const response = await fetch(url, { headers: { "Accept": "application/json" } })
      if (!response.ok) throw new Error("network")
      const data = await response.json()
      if (data.subdomain !== this.inputTarget.value.trim().toLowerCase()) return
      this.#setStatus(data.message, data.available ? "ok" : "bad")
    } catch (_) {
      this.#setStatus("Couldn't check — try again.", "bad")
    }
  }

  #setStatus(message, state) {
    const el = this.statusTarget
    el.textContent = message
    el.className = "micro mt-1.5 text-xs"
    if (state === "ok")  el.style.color = "var(--color-accent-bright)"
    if (state === "bad") el.style.color = "#c0492f"
    if (state === "neutral") el.style.color = "var(--color-ink-soft)"
  }
}
