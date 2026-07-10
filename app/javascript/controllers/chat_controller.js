import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messagesContainer", "messagesArea", "messageInput", "messageForm", "sendButton", "statusMessage", "messageTemplate", "fileInput", "fileForm", "filePreview", "fileName", "fileSize", "fileIcon", "fileCaption", "fileSendButton"]
  static values = { customerId: Number, customerName: String }

  connect() {
    this.loadMessages()
    this.scrollToBottom()
    this.startAutoSync()
  }

  disconnect() {
    this.stopAutoSync()
  }

  async loadMessages() {
    try {
      const csrfToken = document.querySelector('[name="csrf-token"]')?.content
      
      const response = await fetch(`/customers/${this.customerIdValue}/messages.json`, {
        method: 'GET',
        credentials: 'same-origin',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': csrfToken || ''
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        this.renderMessages(data.messages || [])
      } else {
        console.error('Failed to load messages:', response.status, response.statusText)
        this.showStatus(`Failed to load messages: ${response.status}`, 'error')
      }
    } catch (error) {
      console.error('Error loading messages:', error)
      this.showStatus('Error loading messages', 'error')
    }
  }

  renderMessages(messages) {
    this.messagesAreaTarget.innerHTML = ''
    
    if (!messages || messages.length === 0) {
      this.messagesAreaTarget.innerHTML = `
        <div class="flex justify-center items-center py-8">
          <div class="text-gray-500 text-sm">No messages yet. Start the conversation!</div>
        </div>
      `
      return
    }

    messages.forEach(message => {
      this.addMessageToUI(message)
    })
    
    this.scrollToBottom()
  }

  addMessageToUI(message) {
    const template = this.messageTemplateTarget.content.cloneNode(true)
    const messageItem = template.querySelector('.message-item')
    
    const isInbound = message.direction === 'inbound'
    const messageElement = messageItem.querySelector(isInbound ? '.message-inbound' : '.message-outbound')
    const timeElement = isInbound ? messageItem.querySelector('.message-time') : messageItem.querySelector('.message-time-outbound')
    
    messageElement.classList.remove('hidden')
    if (!isInbound) {
      timeElement.classList.remove('hidden')
    }
    
    // Set customer initial for inbound messages
    if (isInbound) {
      const customerInitial = messageElement.querySelector('.customer-initial')
      if (customerInitial) {
        customerInitial.textContent = this.customerNameValue ? this.customerNameValue[0].toUpperCase() : 'C'
      }
    }
    
    const contentElement = messageElement.querySelector('.message-content')
    const attachmentElement = messageElement.querySelector('.message-attachment')
    
    if (message.message_type === 'chat') {
      contentElement.textContent = message.content
    } else {
      const typeLabel = message.message_type.charAt(0).toUpperCase() + message.message_type.slice(1)
      const caption = message.content && message.content !== 'Content' ? message.content : ''

      if (caption) {
        contentElement.textContent = caption
      } else {
        contentElement.classList.add('hidden')
      }

      attachmentElement.classList.remove('hidden')
      if (message.has_attachment && message.attachment_url) {
        attachmentElement.innerHTML = `
          <a href="${message.attachment_url}" target="_blank" class="inline-flex items-center space-x-2 px-3 py-1.5 bg-white/20 border border-current/10 rounded-md hover:bg-white/30 transition-colors text-xs font-medium">
            <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4"/>
            </svg>
            <span>Download ${typeLabel}</span>
          </a>
        `
      } else {
        attachmentElement.innerHTML = `
          <span class="inline-flex items-center space-x-1 text-xs opacity-75">
            <svg class="h-3.5 w-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13"/>
            </svg>
            <span>${typeLabel} message</span>
          </span>
        `
      }
    }
    
    // Set timestamp
    timeElement.textContent = message.formatted_time
    
    this.messagesAreaTarget.appendChild(messageItem)
  }

  createAttachmentHtml(message) {
    const { message_type, attachment_url, attachment_filename } = message
    
    switch (message_type) {
      case 'image':
        return `
          <div class="attachment-item">
            <a href="${attachment_url}" target="_blank" class="block">
              <img src="${attachment_url}" alt="${attachment_filename}" class="max-w-full h-auto rounded-md border border-gray-200 hover:opacity-90 transition-opacity">
            </a>
            <p class="text-xs text-gray-600 mt-1">${attachment_filename}</p>
          </div>
        `
      
      case 'document':
        const icon = this.getDocumentIcon(attachment_filename)
        return `
          <div class="attachment-item">
            <a href="${attachment_url}" target="_blank" class="flex items-center space-x-2 p-2 bg-white border border-gray-200 rounded-md hover:bg-gray-50 transition-colors">
              <div class="flex-shrink-0">
                ${icon}
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium text-gray-900 truncate">${attachment_filename}</p>
                <p class="text-xs text-gray-500">Document</p>
              </div>
            </a>
          </div>
        `
      
      case 'audio':
        return `
          <div class="attachment-item">
            <div class="flex items-center space-x-2 p-2 bg-white border border-gray-200 rounded-md">
              <div class="flex-shrink-0">
                <svg class="h-6 w-6 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 12.536a4 4 0 010-1.072m0 1.072a4 4 0 01-7.072 0m7.072 0L12 16.464m3.536-3.928a8 8 0 010-1.072M8.464 8.464a8 8 0 010 7.072"/>
                </svg>
              </div>
              <div class="flex-1">
                <p class="text-sm font-medium text-gray-900">${attachment_filename}</p>
                <audio controls class="w-full mt-1">
                  <source src="${attachment_url}" type="audio/mpeg">
                  Your browser does not support the audio element.
                </audio>
              </div>
            </div>
          </div>
        `
      
      case 'video':
        return `
          <div class="attachment-item">
            <div class="bg-white border border-gray-200 rounded-md overflow-hidden">
              <video controls class="w-full max-w-xs">
                <source src="${attachment_url}" type="video/mp4">
                Your browser does not support the video element.
              </video>
              <p class="text-xs text-gray-600 p-2">${attachment_filename}</p>
            </div>
          </div>
        `
      
      default:
        return `
          <div class="attachment-item">
            <a href="${attachment_url}" target="_blank" class="flex items-center space-x-2 p-2 bg-white border border-gray-200 rounded-md hover:bg-gray-50 transition-colors">
              <div class="flex-shrink-0">
                <svg class="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                </svg>
              </div>
              <div class="flex-1">
                <p class="text-sm font-medium text-gray-900">${attachment_filename}</p>
                <p class="text-xs text-gray-500">${message_type}</p>
              </div>
            </a>
          </div>
        `
    }
  }

  getDocumentIcon(filename) {
    const extension = filename.split('.').pop().toLowerCase()
    
    switch (extension) {
      case 'pdf':
        return `
          <svg class="h-6 w-6 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
          </svg>
        `
      case 'doc':
      case 'docx':
        return `
          <svg class="h-6 w-6 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
          </svg>
        `
      case 'xls':
      case 'xlsx':
        return `
          <svg class="h-6 w-6 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19v-6a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2a2 2 0 002-2zm0 0V9a2 2 0 012-2h2a2 2 0 012 2v10m-6 0a2 2 0 002 2h2a2 2 0 002-2m0 0V5a2 2 0 012-2h2a2 2 0 012 2v14a2 2 0 01-2 2h-2a2 2 0 01-2-2z"/>
          </svg>
        `
      default:
        return `
          <svg class="h-6 w-6 text-gray-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
          </svg>
        `
    }
  }

  async sendMessage(event) {
    event.preventDefault()
    
    const messageContent = this.messageInputTarget.value.trim()
    if (!messageContent) return
    
    this.sendButtonTarget.disabled = true
    this.sendButtonTarget.innerHTML = 'Sending...'
    
    try {
      const response = await fetch(`/customers/${this.customerIdValue}/messages`, {
        method: 'POST',
        credentials: 'same-origin',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({
          message: { content: messageContent }
        })
      })
      
      const result = await response.json()
      
      if (response.ok && result.success) {
        this.messageInputTarget.value = ''
        this.showStatus('Message sent successfully', 'success')
        
        // Add the sent message to UI immediately
        const sentMessage = {
          id: Date.now(),
          content: messageContent,
          direction: 'outbound',
          message_type: 'text',
          status: 'sent',
          created_at: new Date().toISOString(),
          formatted_time: new Date().toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit' }),
          has_attachment: false,
          attachment_url: null,
          attachment_filename: null
        }
        
        this.addMessageToUI(sentMessage)
        this.scrollToBottom()
        
        // Refresh messages after a short delay to get any new incoming messages
        setTimeout(() => this.loadMessages(), 2000)
      } else {
        this.showStatus(result.error || 'Failed to send message', 'error')
      }
    } catch (error) {
      console.error('Error sending message:', error)
      this.showStatus('Error sending message', 'error')
    } finally {
      this.sendButtonTarget.disabled = false
      this.sendButtonTarget.innerHTML = `
        <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"/>
        </svg>
        <span class="ml-1">Send</span>
      `
    }
  }

  handleKeydown(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault()
      this.sendMessage(event)
    }
  }

  refreshMessages() {
    this.loadMessages()
  }

  async syncMessages() {
    try {
      const csrfToken = document.querySelector('[name="csrf-token"]')?.content
      
      const response = await fetch(`/customers/${this.customerIdValue}/messages/sync`, {
        method: 'PATCH',
        credentials: 'same-origin',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': csrfToken || ''
        }
      })
      
      if (response.ok) {
        const result = await response.json()
        if (result.success) {
          this.showStatus(`Synced ${result.messages_count} messages`, 'success')
          // Refresh messages after sync
          this.loadMessages()
        } else {
          this.showStatus(result.error || 'Failed to sync messages', 'error')
        }
      } else {
        this.showStatus('Failed to sync messages', 'error')
      }
    } catch (error) {
      console.error('Error syncing messages:', error)
      this.showStatus('Error syncing messages', 'error')
    }
  }

  scrollToBottom() {
    setTimeout(() => {
      this.messagesContainerTarget.scrollTop = this.messagesContainerTarget.scrollHeight
    }, 100)
  }

  showStatus(message, type) {
    const statusElement = this.statusMessageTarget
    statusElement.textContent = message
    statusElement.className = `mt-2 text-sm ${type === 'error' ? 'text-red-600' : 'text-green-600'}`
    statusElement.classList.remove('hidden')
    
    setTimeout(() => {
      statusElement.classList.add('hidden')
    }, 3000)
  }

  // File handling methods
  openFileDialog() {
    this.fileInputTarget.click()
  }

  handleFileSelect(event) {
    const file = event.target.files[0]
    if (!file) return

    // Validate file type first
    const allowedTypes = [
      'image/jpeg', 'image/jpg', 'image/png', 'image/gif', 'image/webp',
      'video/mp4', 'video/3gp', 'video/mov', 'video/avi', 'video/webm',
      'audio/mp3', 'audio/wav', 'audio/ogg', 'audio/m4a', 'audio/mpeg', 'audio/flac',
      'application/pdf', 'application/msword', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'application/vnd.ms-excel', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'application/zip', 'text/plain', 'text/csv', 'application/json', 'application/xml'
    ]

    if (!allowedTypes.includes(file.type)) {
      this.showStatus('File type not supported', 'error')
      return
    }

    // Validate file size based on type (more realistic WhatsApp API limits)
    const fileSizeValidation = this.validateFileSize(file)
    if (!fileSizeValidation.valid) {
      this.showStatus(fileSizeValidation.message, 'error')
      return
    }

    // Show file preview
    this.showFilePreview(file)
  }

  validateFileSize(file) {
    const fileType = file.type
    const fileSizeMB = file.size / (1024 * 1024)
    
    // Define size limits based on file type (in MB)
    let maxSize = 5 // Default 5MB for most files
    let typeCategory = 'file'
    
    if (fileType.startsWith('image/')) {
      maxSize = 5 // 5MB for images
      typeCategory = 'image'
    } else if (fileType.startsWith('video/')) {
      maxSize = 16 // 16MB for videos (but WhatsApp API might have lower limits)
      typeCategory = 'video'
    } else if (fileType.startsWith('audio/')) {
      maxSize = 16 // 16MB for audio
      typeCategory = 'audio'
    } else if (fileType === 'application/pdf' || 
               fileType.includes('document') || 
               fileType.includes('spreadsheet') ||
               fileType.includes('presentation') ||
               fileType.includes('text/')) {
      maxSize = 5 // 5MB for documents
      typeCategory = 'document'
    }
    
    if (fileSizeMB > maxSize) {
      return {
        valid: false,
        message: `${typeCategory} files must be less than ${maxSize}MB. Your file is ${fileSizeMB.toFixed(1)}MB.`
      }
    }
    
    // Additional warning for larger files
    if (fileSizeMB > 2) {
      // Still allow but warn
      console.warn(`Large file detected: ${fileSizeMB.toFixed(1)}MB. Upload may be slow or fail.`)
    }
    
    return { valid: true }
  }

  showFilePreview(file) {
    // Update file info
    this.fileNameTarget.textContent = file.name
    this.fileSizeTarget.textContent = this.formatFileSize(file.size)
    
    // Set appropriate icon
    this.fileIconTarget.innerHTML = this.getFileIcon(file.type)
    
    // Show preview container
    this.filePreviewTarget.classList.remove('hidden')
    
    // Hide text message form and show file form
    this.messageFormTarget.classList.add('hidden')
  }

  async sendFile(event) {
    event.preventDefault()
    
    const file = this.fileInputTarget.files[0]
    if (!file) return

    const caption = this.fileCaptionTarget.value.trim()
    
    // Disable send button and show loading state
    this.fileSendButtonTarget.disabled = true
    this.fileSendButtonTarget.innerHTML = `
      <svg class="animate-spin -ml-1 mr-2 h-4 w-4 text-white" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      Sending...
    `
    
    // Create FormData for file upload
    const formData = new FormData()
    formData.append('file', file)
    if (caption) {
      formData.append('caption', caption)
    }

    try {
      const response = await fetch(`/customers/${this.customerIdValue}/messages`, {
        method: 'POST',
        credentials: 'same-origin',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: formData
      })
      
      const result = await response.json()
      
      if (response.ok && result.success) {
        this.showStatus('File sent successfully', 'success')
        this.cancelFile()
        
        // Refresh messages after a short delay
        setTimeout(() => this.loadMessages(), 2000)
      } else {
        // Show specific error message from server
        let errorMessage = result.error || 'Failed to send file'
        
        // Add helpful context for common errors
        if (errorMessage.includes('size')) {
          errorMessage += '. Try compressing the file or using a smaller file.'
        } else if (errorMessage.includes('type') || errorMessage.includes('format')) {
          errorMessage += '. Please check the supported file formats below.'
        } else if (response.status >= 500) {
          errorMessage = 'Server error occurred. Please try again with a smaller file.'
        } else if (response.status === 413) {
          errorMessage = 'File too large. Please use a smaller file (max 5MB for most files).'
        }
        
        this.showStatus(errorMessage, 'error')
      }
    } catch (error) {
      console.error('Error sending file:', error)
      
      // Provide more helpful error messages
      let errorMessage = 'Error sending file'
      if (error.name === 'TypeError' && error.message.includes('fetch')) {
        errorMessage = 'Network error. Please check your connection and try again.'
      } else if (error.message.includes('timeout')) {
        errorMessage = 'Upload timed out. Try using a smaller file.'
      }
      
      this.showStatus(errorMessage, 'error')
    } finally {
      // Re-enable send button and restore original text
      this.fileSendButtonTarget.disabled = false
      this.fileSendButtonTarget.innerHTML = `
        <svg class="h-4 w-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"/>
        </svg>
        Send File
      `
    }
  }

  cancelFile() {
    // Clear file input
    this.fileInputTarget.value = ''
    this.fileCaptionTarget.value = ''
    
    // Hide preview and show text form
    this.filePreviewTarget.classList.add('hidden')
    this.messageFormTarget.classList.remove('hidden')
  }

  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes'
    
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }

  getFileIcon(fileType) {
    if (fileType.startsWith('image/')) {
      return `
        <svg class="h-6 w-6 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
        </svg>
      `
    } else if (fileType.startsWith('video/')) {
      return `
        <svg class="h-6 w-6 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
        </svg>
      `
    } else if (fileType.startsWith('audio/')) {
      return `
        <svg class="h-6 w-6 text-purple-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 19V6l12-3v13M9 19c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zm12-3c0 1.105-1.343 2-3 2s-3-.895-3-2 1.343-2 3-2 3 .895 3 2zM9 10l12-3"/>
        </svg>
      `
    } else if (fileType === 'application/pdf') {
      return `
        <svg class="h-6 w-6 text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
        </svg>
      `
    } else {
      return `
        <svg class="h-6 w-6 text-gray-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
        </svg>
      `
    }
  }

  // Auto-sync functionality
  startAutoSync() {
    // Clear any existing interval
    this.stopAutoSync()
    
    // Set up interval to sync messages every 30 seconds (30000ms)
    this.autoSyncInterval = setInterval(() => {
      this.autoSyncMessages()
    }, 20000)
    
    console.log('Auto-sync started: Messages will be synced every 30 seconds')
  }

  stopAutoSync() {
    if (this.autoSyncInterval) {
      clearInterval(this.autoSyncInterval)
      this.autoSyncInterval = null
      console.log('Auto-sync stopped')
    }
  }

  async autoSyncMessages() {
    try {
      const csrfToken = document.querySelector('[name="csrf-token"]')?.content
      
      const response = await fetch(`/customers/${this.customerIdValue}/messages/sync`, {
        method: 'PATCH',
        credentials: 'same-origin',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': csrfToken || ''
        }
      })
      
      if (response.ok) {
        const result = await response.json()
        if (result.success && result.messages_count > 0) {
          console.log(`Auto-sync: Found ${result.messages_count} new messages`)
          // Refresh messages to show new ones
          this.loadMessages()
        }
      }
    } catch (error) {
      console.error('Auto-sync error:', error)
      // Don't show user errors for background sync to avoid spam
    }
  }
}