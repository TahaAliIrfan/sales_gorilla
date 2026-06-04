import { Controller } from "@hotwired/stimulus"

// Toggles the credentials/provider form on a Settings > Features card.
// Default state shows a compact summary (provider, status). Clicking Edit
// reveals the form; Cancel collapses it back.
export default class extends Controller {
  static targets = ["summary", "form"]

  connect() {
    this.collapse()
  }

  edit(event) {
    event.preventDefault()
    this.expand()
  }

  cancel(event) {
    event.preventDefault()
    this.collapse()
  }

  expand() {
    this.summaryTarget.classList.add("hidden")
    this.formTarget.classList.remove("hidden")
    // Focus first input for keyboard users.
    const firstInput = this.formTarget.querySelector("input, select")
    if (firstInput) firstInput.focus()
  }

  collapse() {
    this.formTarget.classList.add("hidden")
    this.summaryTarget.classList.remove("hidden")
  }
}
