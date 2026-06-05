// app/javascript/controllers/relay/copy_controller.js
// Copies the nearest text target's content to the clipboard. Used on the AI
// analysis detail page in place of the legacy inline copyToClipboard() script.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["text"]

  copy(event) {
    const card = event.currentTarget.closest("[data-relay--copy-target], .rl-card") || this.element
    const source = card.querySelector('[data-relay--copy-target="text"]') ||
      (this.hasTextTarget ? this.textTarget : null)
    const text = source ? source.innerText : ""
    if (!text) return
    navigator.clipboard.writeText(text).then(
      () => {
        const btn = event.currentTarget
        const original = btn.innerHTML
        btn.textContent = "Copied!"
        setTimeout(() => { btn.innerHTML = original }, 1500)
      },
      (err) => console.error("Could not copy text:", err)
    )
  }
}
