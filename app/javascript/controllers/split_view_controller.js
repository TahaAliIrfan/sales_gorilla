import { Controller } from "@hotwired/stimulus"

// Customers split view: compact list on the left, a Turbo-Frame detail pane on
// the right. Clicking a row highlights it and (on narrow screens) reveals the
// pane as a full-screen overlay. The frame itself is loaded by the row link's
// data-turbo-frame="customer_preview".
export default class extends Controller {
  static targets = ["row", "pane"]

  select(event) {
    const row = event.currentTarget.closest('[data-split-view-target="row"]')
    this.rowTargets.forEach((r) => r.classList.toggle("sv-active", r === row))

    // On mobile/tablet the pane is hidden until a row is chosen.
    if (window.innerWidth < 1024 && this.hasPaneTarget) {
      this.paneTarget.classList.add("sv-open")
    }
  }

  close() {
    if (this.hasPaneTarget) this.paneTarget.classList.remove("sv-open")
  }
}
