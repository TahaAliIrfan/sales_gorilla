// app/javascript/controllers/relay/dropdown_controller.js
// Generic disclosure: toggles [data-relay--dropdown-target="menu"],
// closes on outside click and Escape.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]

  connect() {
    this.close = this.close.bind(this)
    this.onKeydown = (e) => { if (e.key === "Escape") this.close() }
  }

  toggle(event) {
    event.stopPropagation()
    this.menuTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.menuTarget.hidden = false
    document.addEventListener("click", this.close)
    document.addEventListener("keydown", this.onKeydown)
  }

  close() {
    this.menuTarget.hidden = true
    document.removeEventListener("click", this.close)
    document.removeEventListener("keydown", this.onKeydown)
  }

  noop(event) { event.stopPropagation() }

  disconnect() { this.close() }
}
