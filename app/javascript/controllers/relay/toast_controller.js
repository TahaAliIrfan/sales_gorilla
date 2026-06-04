// app/javascript/controllers/relay/toast_controller.js
// Auto-dismisses server-rendered toasts after 2.6s (matches prototype).
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item"]

  itemTargetConnected(el) {
    setTimeout(() => {
      el.style.transition = "opacity .3s var(--ease-out)"
      el.style.opacity = "0"
      setTimeout(() => el.remove(), 300)
    }, 2600)
  }
}
