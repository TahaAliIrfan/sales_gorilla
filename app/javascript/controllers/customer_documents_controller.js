import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

export default class extends Controller {
  static targets = ["progress", "progressBar", "form"]

  connect() {
    this.uploadProgress = {}
    this.totalFiles = 0
    this.pendingUploads = 0
    this.blobIds = []
  }

  upload(event) {
    event.preventDefault()
    
    // Show progress bar
    this.progressTarget.classList.remove('hidden')
    
    // Reset progress tracking
    this.uploadProgress = {}
    this.blobIds = []
    this.totalFiles = event.target.files.length
    this.pendingUploads = this.totalFiles
    
    // Upload each file
    Array.from(event.target.files).forEach(file => {
      this.uploadFile(file)
    })
  }

  uploadFile(file) {
    const upload = new DirectUpload(file, this.uploadUrl, this)
    this.uploadProgress[file.name] = 0
    
    upload.create((error, blob) => {
      if (error) {
        console.error('Error uploading file:', error)
      } else {
        // Store the signed blob ID
        this.blobIds.push(blob.signed_id)
      }
      
      // Update progress
      this.uploadProgress[file.name] = 100
      this.updateTotalProgress()
      
      // Decrement pending uploads
      this.pendingUploads--
      
      // If all files are uploaded, submit the form
      if (this.pendingUploads === 0) {
        this.submitForm()
      }
    })
  }

  submitForm() {
    // Clear any existing hidden fields
    const existingFields = this.formTarget.querySelectorAll('input[name="customer[documents][]"]')
    existingFields.forEach(field => field.remove())
    
    // Add hidden fields for each blob ID
    this.blobIds.forEach(blobId => {
      const hiddenField = document.createElement('input')
      hiddenField.setAttribute("type", "hidden")
      hiddenField.setAttribute("value", blobId)
      hiddenField.setAttribute("name", "customer[documents][]")
      this.formTarget.appendChild(hiddenField)
    })
    
    // Submit the form
    this.formTarget.requestSubmit()
  }

  // DirectUpload delegate methods
  directUploadWillStoreFileWithXHR(xhr) {
    xhr.upload.addEventListener("progress", event => {
      const progress = event.loaded / event.total * 100
      this.uploadProgress[event.target.upload.file.name] = progress
      this.updateTotalProgress()
    })
  }

  updateTotalProgress() {
    const total = Object.values(this.uploadProgress).reduce((a, b) => a + b, 0)
    const percentage = Math.round(total / (this.totalFiles * 100) * 100)
    
    // Update progress bar
    this.progressBarTarget.style.width = `${percentage}%`
    this.progressBarTarget.textContent = `${percentage}%`
    
    // Hide progress bar when complete
    if (percentage === 100) {
      setTimeout(() => {
        this.progressTarget.classList.add('hidden')
      }, 1000)
    }
  }

  get uploadUrl() {
    return "/rails/active_storage/direct_uploads"
  }
} 