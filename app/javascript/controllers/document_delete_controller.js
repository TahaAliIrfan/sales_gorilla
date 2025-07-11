import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  handleDelete(event) {
    const form = event.target
    const button = form.querySelector('button')
    
    if (button) {
      // Show loading state
      button.disabled = true
      button.classList.add('opacity-50', 'cursor-not-allowed')
      
      const originalContent = button.innerHTML
      button.innerHTML = `
        <svg class="animate-spin h-4 w-4 mr-1" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Deleting...
      `
      
      // Reset button if form submission fails
      setTimeout(() => {
        if (button) {
          button.disabled = false
          button.classList.remove('opacity-50', 'cursor-not-allowed')
          button.innerHTML = originalContent
        }
      }, 5000)
    }
  }
} 