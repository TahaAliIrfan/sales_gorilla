import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container"]
  
  connect() {
    // Add keydown event listener for ESC key
    this.escapeHandler = this.closeWithKeyboard.bind(this)
    document.addEventListener("keydown", this.escapeHandler)
  }
  
  disconnect() {
    document.removeEventListener("keydown", this.escapeHandler)
  }
  
  closeBackground(event) {
    if (event.target === this.element) {
      this.close()
    }
  }
  
  closeWithKeyboard(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }
  
  close() {
    this.element.classList.add("hidden")
  }
} 