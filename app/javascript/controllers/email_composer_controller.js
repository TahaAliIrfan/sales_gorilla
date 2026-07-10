import { Controller } from "@hotwired/stimulus"

// Rich Text Email Composer Controller
// Handles the contenteditable rich text editor for composing emails
export default class extends Controller {
  static targets = ["editor", "body", "subject", "attachments", "attachmentList", "sendButton", "form"]
  static values = { placeholder: String }

  connect() {
    this.fileList = new DataTransfer()
    this.setupPlaceholder()
    this.setupKeyboardShortcuts()
  }

  setupPlaceholder() {
    if (this.hasEditorTarget && this.placeholderValue) {
      this.editorTarget.setAttribute('data-placeholder', this.placeholderValue)
    }
  }

  setupKeyboardShortcuts() {
    if (this.hasEditorTarget) {
      this.editorTarget.addEventListener('keydown', this.handleKeydown.bind(this))
    }
  }

  handleKeydown(e) {
    if (e.ctrlKey || e.metaKey) {
      switch(e.key.toLowerCase()) {
        case 'b':
          e.preventDefault()
          this.bold()
          break
        case 'i':
          e.preventDefault()
          this.italic()
          break
        case 'u':
          e.preventDefault()
          this.underline()
          break
        case 'z':
          if (e.shiftKey) {
            e.preventDefault()
            this.redo()
          }
          break
        case 'y':
          e.preventDefault()
          this.redo()
          break
      }
    }
  }

  execCommand(command, value = null) {
    document.execCommand(command, false, value)
    if (this.hasEditorTarget) {
      this.editorTarget.focus()
    }
  }

  // Text formatting
  bold() { this.execCommand('bold') }
  italic() { this.execCommand('italic') }
  underline() { this.execCommand('underline') }
  strikeThrough() { this.execCommand('strikeThrough') }

  // Font
  fontSize(event) {
    const value = event.target.value
    this.execCommand('fontSize', value)
  }

  foreColor(event) {
    const value = event.target.value
    this.execCommand('foreColor', value)
  }

  hiliteColor(event) {
    const value = event.target.value
    this.execCommand('hiliteColor', value)
  }

  // Lists
  insertUnorderedList() { this.execCommand('insertUnorderedList') }
  insertOrderedList() { this.execCommand('insertOrderedList') }

  // Alignment
  justifyLeft() { this.execCommand('justifyLeft') }
  justifyCenter() { this.execCommand('justifyCenter') }
  justifyRight() { this.execCommand('justifyRight') }
  justifyFull() { this.execCommand('justifyFull') }

  // Indentation
  indent() { this.execCommand('indent') }
  outdent() { this.execCommand('outdent') }

  // Insert
  insertHorizontalRule() { this.execCommand('insertHorizontalRule') }

  // Links
  createLink() {
    const url = prompt('Enter the link URL:', 'https://')
    if (url) {
      this.execCommand('createLink', url)
    }
  }

  unlink() { this.execCommand('unlink') }

  // Format
  formatBlock(event) {
    const value = event.target.value
    if (value) {
      this.execCommand('formatBlock', '<' + value + '>')
      event.target.value = '' // Reset dropdown
    }
  }

  removeFormat() { this.execCommand('removeFormat') }

  // Undo/Redo
  undo() { this.execCommand('undo') }
  redo() { this.execCommand('redo') }

  // Handle file attachments
  handleAttachments(event) {
    if (!this.hasAttachmentListTarget) return

    // Store files in a DataTransfer to allow manipulation
    if (!this.fileList) {
      this.fileList = new DataTransfer()
    }

    // Add new files to the list
    const newFiles = event.target.files
    Array.from(newFiles).forEach((file) => {
      // Check for duplicates
      let isDuplicate = false
      for (let i = 0; i < this.fileList.files.length; i++) {
        if (this.fileList.files[i].name === file.name && this.fileList.files[i].size === file.size) {
          isDuplicate = true
          break
        }
      }
      if (!isDuplicate) {
        this.fileList.items.add(file)
      }
    })

    // Update the input's files
    this.attachmentsTarget.files = this.fileList.files

    this.renderAttachmentList()
  }

  renderAttachmentList() {
    if (!this.hasAttachmentListTarget) return

    this.attachmentListTarget.innerHTML = ''
    
    if (!this.fileList || this.fileList.files.length === 0) return

    Array.from(this.fileList.files).forEach((file, index) => {
      const chip = document.createElement('div')
      chip.className = 'inline-flex items-center px-2 py-1 bg-emerald-50 border border-emerald-200 rounded text-xs text-emerald-700 group'
      chip.innerHTML = `
        <svg class="h-3 w-3 mr-1 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13" />
        </svg>
        <span class="truncate max-w-[150px]" title="${this.escapeHtml(file.name)}">${this.escapeHtml(file.name)}</span>
        <span class="text-emerald-500 ml-1">(${this.formatFileSize(file.size)})</span>
        <button type="button" class="ml-1 text-emerald-400 hover:text-red-500 transition-colors" data-index="${index}" data-action="click->email-composer#removeAttachment">
          <svg class="h-3 w-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      `
      this.attachmentListTarget.appendChild(chip)
    })
  }

  removeAttachment(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const index = parseInt(event.currentTarget.dataset.index)
    
    if (this.fileList && index >= 0 && index < this.fileList.files.length) {
      // Create new DataTransfer without the removed file
      const newFileList = new DataTransfer()
      Array.from(this.fileList.files).forEach((file, i) => {
        if (i !== index) {
          newFileList.items.add(file)
        }
      })
      this.fileList = newFileList
      this.attachmentsTarget.files = this.fileList.files
      this.renderAttachmentList()
    }
  }

  formatFileSize(bytes) {
    if (bytes === 0) return '0 B'
    const k = 1024
    const sizes = ['B', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i]
  }

  // Form submission
  submit(event) {
    // Copy editor content to hidden input
    if (this.hasEditorTarget && this.hasBodyTarget) {
      this.bodyTarget.value = this.editorTarget.innerHTML
    }

    // Validate content
    if (this.hasEditorTarget && !this.editorTarget.textContent?.trim()) {
      event.preventDefault()
      alert('Please write an email message')
      return false
    }

    // Update button state
    if (this.hasSendButtonTarget) {
      this.sendButtonTarget.disabled = true
      this.sendButtonTarget.innerHTML = `
        <svg class="animate-spin h-4 w-4 mr-2" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        Sending...
      `
    }
  }

  // Reset form
  reset() {
    if (this.hasFormTarget) {
      this.formTarget.reset()
    }
    if (this.hasEditorTarget) {
      this.editorTarget.innerHTML = ''
    }
    // Reset file list
    this.fileList = new DataTransfer()
    if (this.hasAttachmentsTarget) {
      this.attachmentsTarget.files = this.fileList.files
    }
    if (this.hasAttachmentListTarget) {
      this.attachmentListTarget.innerHTML = ''
    }
    if (this.hasSendButtonTarget) {
      this.sendButtonTarget.disabled = false
      this.sendButtonTarget.innerHTML = `
        <svg class="h-4 w-4 mr-2" fill="none" viewBox="0 0 24 24" stroke="currentColor">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8" />
        </svg>
        Send Email
      `
    }
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
