import { Controller } from "@hotwired/stimulus"

// Recalculates a customer's lead score (rules + Claude AI) via the JSON endpoint,
// then reloads the detail pane's Turbo Frame to show the fresh score.
export default class extends Controller {
  static values = { url: String, previewUrl: String }
  static targets = ["button", "buttonLabel"]

  async recalc(event) {
    event.preventDefault()
    if (this.hasButtonTarget) this.buttonTarget.disabled = true
    if (this.hasButtonLabelTarget) this.buttonLabelTarget.textContent = "Scoring…"

    try {
      const res = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content,
          Accept: "application/json",
        },
      })
      if (!res.ok) throw new Error(`HTTP ${res.status}`)
      // Reload the pane frame to render the updated score + reason.
      const frame = document.getElementById("customer_preview")
      if (frame && this.hasPreviewUrlValue) frame.setAttribute("src", this.previewUrlValue)
    } catch (e) {
      if (this.hasButtonTarget) this.buttonTarget.disabled = false
      if (this.hasButtonLabelTarget) this.buttonLabelTarget.textContent = "Retry"
    }
  }
}
