import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["viewMode", "editMode", "textarea", "editButton", "editButtonText", "saveButton", "loadingState"]
  static values = { customerId: Number }

  connect() {
    this.originalNotes = this.textareaTarget.value
  }

  toggleEdit() {
    // Toggle between view and edit mode
    this.viewModeTarget.classList.add('hidden')
    this.editModeTarget.classList.remove('hidden')
    this.editButtonTarget.classList.add('hidden')
    
    // Focus on textarea
    this.textareaTarget.focus()
    
    // Move cursor to end
    this.textareaTarget.setSelectionRange(
      this.textareaTarget.value.length,
      this.textareaTarget.value.length
    )
  }

  cancel() {
    // Reset to original notes
    this.textareaTarget.value = this.originalNotes
    
    // Switch back to view mode
    this.editModeTarget.classList.add('hidden')
    this.viewModeTarget.classList.remove('hidden')
    this.editButtonTarget.classList.remove('hidden')
  }

  async save() {
    const notes = this.textareaTarget.value.trim()
    
    // Disable save button and show loading
    this.saveButtonTarget.disabled = true
    this.saveButtonTarget.classList.add('opacity-50', 'cursor-not-allowed')
    
    try {
      const response = await fetch(`/customers/${this.customerIdValue}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Accept': 'application/json'
        },
        body: JSON.stringify({
          customer: {
            notes: notes
          }
        })
      })

      if (response.ok) {
        // Update original notes
        this.originalNotes = notes
        
        // Update view mode content
        const viewContent = this.viewModeTarget.querySelector('p')
        if (notes.length > 0) {
          viewContent.textContent = notes
          viewContent.classList.remove('text-gray-500', 'italic')
          viewContent.classList.add('text-gray-700', 'whitespace-pre-wrap')
        } else {
          viewContent.textContent = 'No notes yet. Click "Edit" to add notes.'
          viewContent.classList.add('text-gray-500', 'italic')
          viewContent.classList.remove('text-gray-700', 'whitespace-pre-wrap')
        }
        
        // Switch back to view mode
        this.editModeTarget.classList.add('hidden')
        this.viewModeTarget.classList.remove('hidden')
        this.editButtonTarget.classList.remove('hidden')
        
        // Show success notification
        this.showNotification('Notes saved successfully', 'success')
      } else {
        const data = await response.json()
        throw new Error(data.error || 'Failed to save notes')
      }
    } catch (error) {
      console.error('Error saving notes:', error)
      this.showNotification(error.message || 'Failed to save notes', 'error')
    } finally {
      // Re-enable save button
      this.saveButtonTarget.disabled = false
      this.saveButtonTarget.classList.remove('opacity-50', 'cursor-not-allowed')
    }
  }

  showNotification(message, type = 'success') {
    // Create notification element
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 z-50 px-6 py-3 rounded-lg shadow-lg ${
      type === 'success' ? 'bg-green-500 text-white' : 'bg-red-500 text-white'
    }`
    
    const iconSvg = type === 'success' 
      ? '<svg class="h-5 w-5 mr-2 inline" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" /></svg>'
      : '<svg class="h-5 w-5 mr-2 inline" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" /></svg>'
    
    notification.innerHTML = iconSvg + message
    
    // Add to page
    document.body.appendChild(notification)
    
    // Animate in
    setTimeout(() => {
      notification.style.transition = 'opacity 0.3s ease-in'
      notification.style.opacity = '1'
    }, 10)
    
    // Remove after 3 seconds
    setTimeout(() => {
      notification.style.opacity = '0'
      setTimeout(() => {
        notification.remove()
      }, 300)
    }, 3000)
  }
}
