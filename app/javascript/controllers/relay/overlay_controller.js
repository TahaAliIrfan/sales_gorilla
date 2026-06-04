// app/javascript/controllers/relay/overlay_controller.js
// Generic modal/drawer: any element with target="panel" (a .scrim wrapper
// for modals, or a .drawer) is shown/hidden. One controller instance wraps
// trigger + panel.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  connect() { this.onKeydown = (e) => { if (e.key === "Escape") this.close() } }

  open() {
    this.panelTarget.hidden = false
    document.addEventListener("keydown", this.onKeydown)
  }

  close() {
    this.panelTarget.hidden = true
    document.removeEventListener("keydown", this.onKeydown)
  }

  backdrop(e) { if (e.target === this.panelTarget) this.close() }

  disconnect() { document.removeEventListener("keydown", this.onKeydown) }
}
