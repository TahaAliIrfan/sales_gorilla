import { Controller } from "@hotwired/stimulus"

// Keeps the live preview in sync with the color pickers and hex inputs on the
// Branding settings page. Also handles preset buttons.
export default class extends Controller {
  static targets = ["preview", "primary", "primaryHex", "accent", "accentHex"]

  syncPrimary(event) {
    const value = event.target.value
    this.primaryHexTarget.value = value
    this.#applyPrimary(value)
  }

  syncPrimaryHex(event) {
    const value = event.target.value
    if (!this.#isHex(value)) return
    this.primaryTarget.value = value
    this.#applyPrimary(value)
  }

  syncAccent(event) {
    const value = event.target.value
    this.accentHexTarget.value = value
    this.#applyAccent(value)
  }

  syncAccentHex(event) {
    const value = event.target.value
    if (!this.#isHex(value)) return
    this.accentTarget.value = value
    this.#applyAccent(value)
  }

  applyPreset(event) {
    const { primary, accent } = event.currentTarget.dataset
    this.primaryTarget.value = primary
    this.primaryHexTarget.value = primary
    this.accentTarget.value = accent
    this.accentHexTarget.value = accent
    this.#applyPrimary(primary)
    this.#applyAccent(accent)
  }

  #applyPrimary(value) {
    this.previewTarget.style.setProperty("--brand-primary", value)
  }

  #applyAccent(value) {
    this.previewTarget.style.setProperty("--brand-accent", value)
  }

  #isHex(value) {
    return /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/.test(value)
  }
}
