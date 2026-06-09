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

  // Mobile off-canvas drawer: toggles a class on the .app shell (this.element).
  // CSS (shell.css, max-width:860px) slides the sidebar in and shows a scrim.
  toggleMobile() {
    this.element.classList.toggle("is-nav-open")
  }

  closeMobile() {
    this.element.classList.remove("is-nav-open")
  }

  apply(collapsed) {
    this.asideTarget.classList.toggle("is-collapsed", collapsed)
    if (this.hasCollapseIconTarget) this.collapseIconTarget.hidden = collapsed
    if (this.hasExpandIconTarget) this.expandIconTarget.hidden = !collapsed
    localStorage.setItem(KEY, collapsed ? "1" : "0")
  }
}
