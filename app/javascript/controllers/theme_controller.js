import { Controller } from "@hotwired/stimulus"

// Toggles the `data-theme` attribute on <html> between "light" and "dark" and
// persists the choice in localStorage.
export default class extends Controller {
  toggle() {
    const next = document.documentElement.dataset.theme === "dark" ? "light" : "dark"
    this.#apply(next)
  }

  set(event) {
    const value = event.currentTarget.dataset.themeValue
    if (value) this.#apply(value)
  }

  #apply(value) {
    document.documentElement.dataset.theme = value
    try { localStorage.setItem("theme", value) } catch (_) {}
  }
}
