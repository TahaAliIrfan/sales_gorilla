import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["textarea"]

  connect() {
    // Add keyboard event listener for better line break handling
    this.textareaTarget.addEventListener('keydown', this.handleKeydown.bind(this))
  }

  disconnect() {
    this.textareaTarget.removeEventListener('keydown', this.handleKeydown.bind(this))
  }

  handleKeydown(event) {
    // Handle Shift+Enter or regular Enter to insert line break
    if (event.key === 'Enter') {
      // Allow default behavior (line break) for both Enter and Shift+Enter
      // This ensures Shift+Enter always creates a new line
      return true
    }
  }

  insertVariable(event) {
    event.preventDefault()
    const variable = event.currentTarget.dataset.variable
    const textarea = this.textareaTarget
    const start = textarea.selectionStart
    const end = textarea.selectionEnd
    const text = textarea.value

    // Insert variable at cursor position
    const before = text.substring(0, start)
    const after = text.substring(end, text.length)
    textarea.value = before + variable + after

    // Move cursor after inserted variable
    const newPosition = start + variable.length
    textarea.selectionStart = newPosition
    textarea.selectionEnd = newPosition

    // Focus back on textarea
    textarea.focus()
  }
}
