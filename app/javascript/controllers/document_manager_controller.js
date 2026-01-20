import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fileInput", "documentsList", "uploadProgress"]
  static values = { customerId: Number }

  connect() {
    console.log("Document manager controller connected")
    this.uploading = false
  }

  async uploadDocument(event) {
    const files = event.target.files
    
    if (!files || files.length === 0) {
      return
    }

    // Prevent multiple simultaneous uploads
    if (this.uploading) {
      console.log("Upload already in progress, ignoring...")
      event.target.value = ''
      return
    }

    this.uploading = true

    // Disable file input during upload
    if (this.hasFileInputTarget) {
      this.fileInputTarget.disabled = true
    }

    // Show upload progress
    if (this.hasUploadProgressTarget) {
      this.uploadProgressTarget.classList.remove('hidden')
    }

    // Create FormData with documents
    const formData = new FormData()
    
    for (let i = 0; i < files.length; i++) {
      formData.append('documents[]', files[i])
    }

    try {
      const response = await fetch(`/customers/${this.customerIdValue}/upload_documents`, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Accept': 'application/json'
        },
        body: formData
      })

      const data = await response.json()
      
      if (response.ok && data.success) {
        // Success - reload the page to show new documents
        this.showNotification(data.message || `Successfully uploaded ${files.length} document(s)`, 'success')
        
        setTimeout(() => {
          window.location.reload()
        }, 1000)
      } else {
        throw new Error(data.error || 'Failed to upload documents')
      }
    } catch (error) {
      console.error('Error uploading documents:', error)
      this.showNotification('Failed to upload documents', 'error')
      
      // Hide progress and re-enable input on error
      if (this.hasUploadProgressTarget) {
        this.uploadProgressTarget.classList.add('hidden')
      }
      if (this.hasFileInputTarget) {
        this.fileInputTarget.disabled = false
      }
      this.uploading = false
    }

    // Reset file input
    event.target.value = ''
  }

  deleteDocument(event) {
    event.preventDefault()
    
    const button = event.currentTarget
    const documentId = button.dataset.documentId
    const documentName = button.dataset.documentName
    
    // Confirm deletion
    if (!confirm(`Are you sure you want to delete "${documentName}"?`)) {
      return
    }

    // Disable button during deletion
    button.disabled = true
    button.classList.add('opacity-50')
    
    this.performDelete(documentId, button)
  }

  async performDelete(documentId, button) {
    try {
      const response = await fetch(`/customers/${this.customerIdValue}?remove_document=${encodeURIComponent(documentId)}`, {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Accept': 'application/json',
          'Content-Type': 'application/json'
        }
      })

      const data = await response.json()

      if (response.ok && data.success) {
        // Success - remove the document card from the DOM
        const documentCard = button.closest('[data-document-id]')
        if (documentCard) {
          documentCard.style.transition = 'opacity 0.3s ease-out, transform 0.3s ease-out'
          documentCard.style.opacity = '0'
          documentCard.style.transform = 'scale(0.9)'
          
          setTimeout(() => {
            documentCard.remove()
            
            // Check if there are any documents left
            const remainingDocuments = this.documentsListTarget.querySelectorAll('[data-document-id]')
            if (remainingDocuments.length === 0) {
              // Show empty state
              this.documentsListTarget.innerHTML = `
                <div class="text-center py-12 bg-gray-50 rounded-lg">
                  <svg class="mx-auto h-12 w-12 text-gray-400" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                  </svg>
                  <h3 class="mt-2 text-sm font-medium text-gray-900">No documents</h3>
                  <p class="mt-1 text-sm text-gray-500">Upload documents to keep them organized</p>
                </div>
              `
            }
          }, 300)
        }
        
        this.showNotification(data.message || 'Document deleted successfully', 'success')
      } else {
        throw new Error(data.error || 'Failed to delete document')
      }
    } catch (error) {
      console.error('Error deleting document:', error)
      this.showNotification(error.message || 'Failed to delete document', 'error')
      
      // Re-enable button
      button.disabled = false
      button.classList.remove('opacity-50')
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
