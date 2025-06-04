import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "backdrop"]

  connect() {
    // Close menu when escape key is pressed
    document.addEventListener('keydown', this.handleKeyDown.bind(this))
  }

  disconnect() {
    document.removeEventListener('keydown', this.handleKeyDown.bind(this))
  }

  open() {
    this.sidebarTarget.classList.remove('-translate-x-full')
    this.backdropTarget.classList.remove('hidden')
    document.body.classList.add('overflow-hidden')
  }

  close() {
    this.sidebarTarget.classList.add('-translate-x-full')
    this.backdropTarget.classList.add('hidden')
    document.body.classList.remove('overflow-hidden')
  }

  handleKeyDown(event) {
    if (event.key === 'Escape') {
      this.close()
    }
  }
} 