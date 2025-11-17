import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "checkbox", "button", "buttonText"]

  connect() {
    this.closeHandler = this.closeOnClickOutside.bind(this)
    document.addEventListener("click", this.closeHandler)
    this.updateButtonText()
  }

  disconnect() {
    document.removeEventListener("click", this.closeHandler)
  }

  toggle(event) {
    event.stopPropagation()
    this.menuTarget.classList.toggle('hidden')
  }

  closeOnClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.menuTarget.classList.add('hidden')
    }
  }

  hide() {
    this.menuTarget.classList.add('hidden')
  }

  checkboxChanged() {
    this.updateButtonText()
  }

  updateButtonText() {
    const selectedCheckboxes = this.checkboxTargets.filter(cb => cb.checked)
    const count = selectedCheckboxes.length

    if (count === 0) {
      this.buttonTextTarget.textContent = "All Sources"
    } else if (count === 1) {
      this.buttonTextTarget.textContent = selectedCheckboxes[0].dataset.label
    } else {
      this.buttonTextTarget.textContent = `${count} Sources Selected`
    }
  }

  getSelectedValues() {
    return this.checkboxTargets
      .filter(cb => cb.checked)
      .map(cb => cb.value)
  }
}
