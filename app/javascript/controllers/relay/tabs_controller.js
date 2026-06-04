// app/javascript/controllers/relay/tabs_controller.js
// DS tabs (.rl-tabs / .rl-tab with is-active) switching same-page panels.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]
  static values = { index: { type: Number, default: 0 } }

  connect() { this.show(this.indexValue) }

  switch(e) { this.show(this.tabTargets.indexOf(e.currentTarget)) }

  show(i) {
    this.tabTargets.forEach((t, j) => t.classList.toggle("is-active", j === i))
    this.panelTargets.forEach((p, j) => (p.hidden = j !== i))
  }
}
