// app/javascript/controllers/relay/sidebar_controller.js
// Collapses the sidebar to icon rail (DS class `is-collapsed`), persisted.
import { Controller } from "@hotwired/stimulus"

const KEY = "relay:sidebar-collapsed"

export default class extends Controller {
  static targets = ["aside", "collapseIcon", "expandIcon"]

  connect() {
    this.apply(localStorage.getItem(KEY) === "1")
  }

  toggle() {
    this.apply(!this.asideTarget.classList.contains("is-collapsed"))
  }

  apply(collapsed) {
    this.asideTarget.classList.toggle("is-collapsed", collapsed)
    if (this.hasCollapseIconTarget) this.collapseIconTarget.hidden = collapsed
    if (this.hasExpandIconTarget) this.expandIconTarget.hidden = !collapsed
    localStorage.setItem(KEY, collapsed ? "1" : "0")
  }
}
