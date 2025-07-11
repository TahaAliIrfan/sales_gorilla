import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

export default class extends Controller {
  static targets = ["progress", "progressBar", "progressText", "form", "dropZone", "fileInput", "fileList", "errorDisplay", "errorMessage"]

  connect() {
    this.uploadProgress = {}
    this.totalFiles = 0
    this.pendingUploads = 0
    this.blobIds = []
    this.isDragOver = false
  }

  // Drag and Drop Event Handlers
  preventDefault(event) {
    event.preventDefault()
    event.stopPropagation()
  }

  handleDragEnter(event) {
    this.preventDefault(event)
    if (!this.isDragOver) {
      this.isDragOver = true
      this.dropZoneTarget.classList.add('border-blue-400', 'bg-blue-50')
      this.dropZoneTarget.classList.remove('border-gray-300')
    }
  }

  handleDragLeave(event) {
    this.preventDefault(event)
    // Only remove drag styles if we're leaving the drop zone entirely
    if (!this.dropZoneTarget.contains(event.relatedTarget)) {
      this.isDragOver = false
      this.dropZoneTarget.classList.remove('border-blue-400', 'bg-blue-50')
      this.dropZoneTarget.classList.add('border-gray-300')
    }
  }

  handleDrop(event) {
    this.preventDefault(event)
    this.isDragOver = false
    this.dropZoneTarget.classList.remove('border-blue-400', 'bg-blue-50')
    this.dropZoneTarget.classList.add('border-gray-300')

    const files = event.dataTransfer.files
    if (files.length > 0) {
      this.processFiles(files)
    }
  }

  upload(event) {
    event.preventDefault()
    this.processFiles(event.target.files)
  }

  processFiles(files) {
    // Hide any previous errors
    this.hideError()
    
    // Validate files before uploading
    const validFiles = this.validateFiles(files)
    if (validFiles.length === 0) {
      return
    }

    // Show progress bar
    this.showProgress()
    
    // Reset progress tracking
    this.uploadProgress = {}
    this.blobIds = []
    this.totalFiles = validFiles.length
    this.pendingUploads = this.totalFiles
    
    // Clear file list display
    this.fileListTarget.innerHTML = ''
    
    // Upload each file
    Array.from(validFiles).forEach(file => {
      this.uploadFile(file)
    })
  }

  validateFiles(files) {
    const validFiles = []
    const errors = []
    
    // Allowed file types
    const allowedTypes = [
      'application/pdf',
      'application/msword',
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.ms-excel',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'text/csv',
      'image/jpeg',
      'image/png',
      'image/gif'
    ]
    
    const maxSize = 10 * 1024 * 1024 // 10MB in bytes
    
    Array.from(files).forEach(file => {
      // Check file type
      if (!allowedTypes.includes(file.type)) {
        errors.push(`${file.name}: Unsupported file type. Please upload PDF, DOC, DOCX, XLS, XLSX, CSV, JPG, PNG, or GIF files.`)
        return
      }
      
      // Check file size
      if (file.size > maxSize) {
        errors.push(`${file.name}: File size too large. Maximum size is 10MB.`)
        return
      }
      
      validFiles.push(file)
    })
    
    // Show errors if any
    if (errors.length > 0) {
      this.showError(errors.join('<br>'))
    }
    
    return validFiles
  }

  uploadFile(file) {
    const upload = new DirectUpload(file, this.uploadUrl, this)
    this.uploadProgress[file.name] = 0
    
    // Add file to progress list
    this.addFileToProgressList(file.name)
    
    upload.create((error, blob) => {
      if (error) {
        console.error('Error uploading file:', error)
        console.error('Error details:', {
          message: error.message,
          status: error.status,
          response: error.response
        })
        
        let errorMessage = 'Unknown error'
        if (error.message) {
          errorMessage = error.message
        } else if (error.status) {
          errorMessage = `HTTP ${error.status} error`
        } else if (error.response) {
          errorMessage = `Server error: ${error.response}`
        }
        
        this.showError(`Failed to upload ${file.name}: ${errorMessage}`)
        this.updateFileProgress(file.name, 'error')
      } else {
        // Store the signed blob ID
        this.blobIds.push(blob.signed_id)
        this.updateFileProgress(file.name, 'complete')
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

  addFileToProgressList(fileName) {
    const fileItem = document.createElement('div')
    fileItem.className = 'flex items-center justify-between'
    fileItem.setAttribute('data-file', fileName)
    fileItem.innerHTML = `
      <span class="text-gray-700">${fileName}</span>
      <span class="file-status text-blue-600">Uploading...</span>
    `
    this.fileListTarget.appendChild(fileItem)
  }

  updateFileProgress(fileName, status) {
    const fileItem = this.fileListTarget.querySelector(`[data-file="${fileName}"]`)
    if (fileItem) {
      const statusElement = fileItem.querySelector('.file-status')
      if (status === 'complete') {
        statusElement.textContent = 'Complete'
        statusElement.className = 'file-status text-green-600'
      } else if (status === 'error') {
        statusElement.textContent = 'Error'
        statusElement.className = 'file-status text-red-600'
      }
    }
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
    
    // Add error handling for network issues
    xhr.addEventListener("error", event => {
      console.error("XHR Error during upload:", event)
      console.error("XHR status:", xhr.status)
      console.error("XHR response:", xhr.responseText)
    })
    
    xhr.addEventListener("timeout", event => {
      console.error("XHR Timeout during upload:", event)
    })
  }

  updateTotalProgress() {
    const total = Object.values(this.uploadProgress).reduce((a, b) => a + b, 0)
    const percentage = Math.round(total / (this.totalFiles * 100) * 100)
    
    // Update progress bar
    this.progressBarTarget.style.width = `${percentage}%`
    this.progressTextTarget.textContent = `${percentage}%`
    
    // Hide progress bar when complete
    if (percentage === 100) {
      setTimeout(() => {
        this.hideProgress()
      }, 2000)
    }
  }

  showProgress() {
    this.progressTarget.classList.remove('hidden')
  }

  hideProgress() {
    this.progressTarget.classList.add('hidden')
    this.fileListTarget.innerHTML = ''
  }

  showError(message) {
    this.errorMessageTarget.innerHTML = message
    this.errorDisplayTarget.classList.remove('hidden')
  }

  hideError() {
    this.errorDisplayTarget.classList.add('hidden')
    this.errorMessageTarget.innerHTML = ''
  }

  get uploadUrl() {
    return "/rails/active_storage/direct_uploads"
  }
} 