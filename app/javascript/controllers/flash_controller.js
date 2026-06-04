import { Controller } from "@hotwired/stimulus"

// Auto-dismisses flash toasts after a short delay; clicking dismisses immediately.
export default class extends Controller {
  connect() {
    this.timeout = setTimeout(() => this.dismiss(), 4500)
  }

  disconnect() {
    if (this.timeout) clearTimeout(this.timeout)
  }

  dismiss() {
    this.element.style.transition = "opacity 200ms ease, transform 200ms ease"
    this.element.style.opacity = "0"
    this.element.style.transform = "translateY(-4px)"
    setTimeout(() => this.element.remove(), 220)
  }
}
