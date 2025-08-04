import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "messages", 
    "messageContainer", 
    "loader", 
    "noMessages", 
    "error", 
    "errorMessage", 
    "refreshButton",
    "messageInput",
    "sendButton",
    "sendingIndicator",
    "sendError",
    "sendErrorMessage",
    "customerSelect",
    "chatHeader",
    "customerName",
    "customerError",
    "customerErrorMessage",
    "attachButton",
    "fileInput",
    "mediaPreview",
    "mediaPreviewIcon",
    "mediaFileName",
    "mediaFileSize",
    "mediaCaptionInput",
    "removeMediaButton",
    "sendMediaButton"
  ]
  
  static values = { 
    apiBaseUrl: String
  }

  connect() {
    this.selectedCustomerId = null
    this.apiBaseUrlValue = this.apiBaseUrlValue || '/api/v1'
    this.selectedFile = null
    
    console.log('WhatsApp Web Chat: Controller connected')
    console.log('API Base URL:', this.apiBaseUrlValue)
    
    // Load customers for selection
    this.loadCustomers()
    
    // Set up auto-refresh (but don't start until customer is selected)
    this.refreshInterval = null
    
    // Set up drag and drop
    this.setupDragAndDrop()
  }
  
  disconnect() {
    this.stopAutoRefresh()
  }
  
  async loadCustomers() {
    try {
      const response = await fetch('/customers', {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      
      const customers = await response.json()
      console.log('Loaded customers:', customers)
      
      if (this.hasCustomerSelectTarget) {
        this.customerSelectTarget.innerHTML = '<option value="">Select a customer...</option>'
        
        customers.forEach(customer => {
          const option = document.createElement('option')
          option.value = customer.id
          option.textContent = `${customer.name || 'Unnamed Customer'} (${customer.phone || 'No phone'})`
          this.customerSelectTarget.appendChild(option)
        })
        
        console.log(`Loaded ${customers.length} customers into dropdown`)
      }
    } catch (error) {
      console.error('Error loading customers:', error)
      this.showCustomerError('Failed to load customers: ' + error.message)
    }
  }
  
  customerSelected(event) {
    const customerId = event.target.value
    
    if (customerId) {
      this.selectedCustomerId = customerId
      this.showCustomerChat(customerId)
      this.startAutoRefresh()
    } else {
      this.selectedCustomerId = null
      this.hideCustomerChat()
      this.stopAutoRefresh()
    }
  }
  
  showCustomerChat(customerId) {
    // Update header
    if (this.hasCustomerNameTarget) {
      const selectedOption = this.customerSelectTarget.selectedOptions[0]
      this.customerNameTarget.textContent = selectedOption.textContent
    }
    
    // Show chat header
    if (this.hasChatHeaderTarget) {
      this.chatHeaderTarget.classList.remove('hidden')
    }
    
    // Hide welcome screen and show messages container
    const welcomeScreen = document.getElementById('welcomeScreen')
    const messagesContainer = document.getElementById('messagesContainer')
    
    if (welcomeScreen) {
      welcomeScreen.classList.add('hidden')
    }
    
    if (messagesContainer) {
      messagesContainer.classList.remove('hidden')
    }
    
    // Load messages for selected customer
    this.fetchCustomerMessages(customerId)
  }
  
  hideCustomerChat() {
    if (this.hasChatHeaderTarget) {
      this.chatHeaderTarget.classList.add('hidden')
    }
    
    // Show welcome screen and hide messages container
    const welcomeScreen = document.getElementById('welcomeScreen')
    const messagesContainer = document.getElementById('messagesContainer')
    
    if (welcomeScreen) {
      welcomeScreen.classList.remove('hidden')
    }
    
    if (messagesContainer) {
      messagesContainer.classList.add('hidden')
    }
    
    // Clear messages
    if (this.hasMessageContainerTarget) {
      this.messageContainerTarget.innerHTML = ''
    }
    if (this.hasNoMessagesTarget) {
      this.noMessagesTarget.classList.add('hidden')
    }
    if (this.hasErrorTarget) {
      this.errorTarget.classList.add('hidden')
    }
  }
  
  startAutoRefresh() {
    this.stopAutoRefresh()
    
    if (this.selectedCustomerId) {
      this.refreshInterval = setInterval(() => {
        if (!this.isSending && this.selectedCustomerId) {
          this.fetchCustomerMessages(this.selectedCustomerId, true)
        }
      }, 5000)
      
      console.log('Auto-refresh started for customer:', this.selectedCustomerId)
    }
  }
  
  stopAutoRefresh() {
    if (this.refreshInterval) {
      clearInterval(this.refreshInterval)
      this.refreshInterval = null
      console.log('Auto-refresh stopped')
    }
  }

  async fetchCustomerMessages(customerId, isAutoRefresh = false) {
    if (!isAutoRefresh) {
      this.loaderTarget.classList.remove('hidden')
      this.noMessagesTarget.classList.add('hidden')
      this.errorTarget.classList.add('hidden')
      
      if (this.hasRefreshButtonTarget) {
        this.refreshButtonTarget.disabled = true
      }
    }
    
    try {
      const url = `${this.apiBaseUrlValue}/whatsapp/customer/${customerId}/messages`
      console.log('Fetching messages from:', url)
      
      const response = await fetch(url, {
        headers: {
          'Accept': 'application/json',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      console.log('Response status:', response.status)
      
      if (!isAutoRefresh) {
        this.loaderTarget.classList.add('hidden')
        
        if (this.hasRefreshButtonTarget) {
          this.refreshButtonTarget.disabled = false
        }
      }
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      
      const data = await response.json()
      console.log('Messages response:', data)
      
      if (!data.success) {
        if (!isAutoRefresh) {
          this.showError(data.error || "Failed to load messages")
        }
        return
      }
      
      const messages = data.data?.messages || []
      console.log('Found messages:', messages.length)
      
      if (messages.length === 0) {
        if (!isAutoRefresh) {
          this.noMessagesTarget.classList.remove('hidden')
        }
        return
      }
      
      this.displayMessages(messages, isAutoRefresh)
      
    } catch (error) {
      console.error('Error fetching messages:', error)
      
      if (!isAutoRefresh) {
        this.showError("Failed to load messages: " + error.message)
        this.loaderTarget.classList.add('hidden')
        
        if (this.hasRefreshButtonTarget) {
          this.refreshButtonTarget.disabled = false
        }
      }
    }
  }
  
  displayMessages(messages, isAutoRefresh = false) {
    const messagesElement = this.messagesTarget
    const wasAtBottom = messagesElement.scrollTop + messagesElement.clientHeight >= messagesElement.scrollHeight - 20
    const oldMessagesCount = this.messageContainerTarget.children.length
    
    // Clear container
    this.messageContainerTarget.innerHTML = ""
    
    // Sort messages by timestamp
    const sortedMessages = messages.sort((a, b) => {
      const timeA = new Date(a.timestamp || a.created_at).getTime()
      const timeB = new Date(b.timestamp || b.created_at).getTime()
      return timeA - timeB
    })
    
    if (sortedMessages.length === 0) {
      this.noMessagesTarget.classList.remove('hidden')
      return
    }
    
    // Display each message
    sortedMessages.forEach(message => {
      const messageElement = this.createMessageElement(message)
      this.messageContainerTarget.appendChild(messageElement)
    })
    
    // Handle scrolling
    const newMessagesCount = this.messageContainerTarget.children.length
    
    if (newMessagesCount > oldMessagesCount && isAutoRefresh) {
      console.log(`✅ Auto-refresh: ${newMessagesCount - oldMessagesCount} new message(s)`)
      this.scrollToBottom()
    } else if (wasAtBottom || !isAutoRefresh) {
      this.scrollToBottom()
    }
  }
  
  createMessageElement(message) {
    const isFromMe = message.is_from_me || message.direction === 'outbound'
    const timestamp = new Date(message.timestamp || message.created_at).toLocaleString()
    const content = message.content || message.body || 'No content'
    
    const messageElement = document.createElement('div')
    messageElement.className = isFromMe 
      ? 'flex flex-col items-end mb-4' 
      : 'flex flex-col items-start mb-4'
    
    const senderInfo = isFromMe 
      ? { name: "You", icon: "user-tie", color: "blue" }
      : { name: "Customer", icon: "user", color: "green" }
    
    messageElement.innerHTML = `
      <div class="flex items-end ${isFromMe ? 'flex-row-reverse' : ''}">
        <div class="flex-shrink-0 h-8 w-8 rounded-full bg-${senderInfo.color}-500 flex items-center justify-center">
          <i class="fas fa-${senderInfo.icon} text-white text-sm"></i>
        </div>
        <div class="${isFromMe ? 'mr-2' : 'ml-2'} ${isFromMe ? 'bg-blue-100 text-blue-800' : 'bg-green-100 text-green-800'} px-4 py-2 rounded-lg max-w-xs sm:max-w-md shadow-sm">
          <div class="text-xs text-${senderInfo.color}-600 font-medium mb-1">${senderInfo.name}</div>
          <p class="text-sm whitespace-pre-wrap">${content}</p>
          ${message.media ? this.createMediaElement(message.media) : ''}
          <p class="text-xs text-gray-500 mt-1 text-right">${timestamp}</p>
        </div>
      </div>
    `
    
    return messageElement
  }
  
  createMediaElement(media) {
    if (!media || !media.url) return ''
    
    const mediaType = media.type || 'document'
    const filename = media.filename || 'file'
    
    switch (mediaType) {
      case 'image':
        return `
          <div class="mt-2">
            <img src="${media.url}" alt="${filename}" class="max-w-xs h-auto rounded cursor-pointer shadow-sm" onclick="window.open('${media.url}', '_blank')">
          </div>`
      case 'video':
        return `
          <div class="mt-2">
            <video controls class="max-w-xs h-auto rounded shadow-sm">
              <source src="${media.url}" type="${media.content_type || 'video/mp4'}">
              Your browser does not support the video tag.
            </video>
          </div>`
      case 'audio':
        return `
          <div class="mt-2">
            <audio controls class="w-64">
              <source src="${media.url}" type="${media.content_type || 'audio/mpeg'}">
              Your browser does not support the audio element.
            </audio>
          </div>`
      default:
        return `
          <div class="mt-2 p-2 bg-gray-100 rounded border">
            <a href="${media.url}" target="_blank" class="inline-flex items-center text-blue-600 hover:text-blue-800">
              <i class="fas fa-file mr-2"></i>
              <div class="flex flex-col">
                <span class="font-medium">${filename}</span>
                <span class="text-xs text-gray-500">${media.size ? this.formatFileSize(media.size) : ''}</span>
              </div>
              <i class="fas fa-download ml-2"></i>
            </a>
          </div>`
    }
  }
  
  scrollToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }
  
  refresh(event) {
    if (event) event.preventDefault()
    
    if (this.selectedCustomerId) {
      console.log('Manual refresh for customer:', this.selectedCustomerId)
      this.fetchCustomerMessages(this.selectedCustomerId)
    }
  }
  
  handleKeyPress(event) {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault()
      this.sendMessage(event)
    }
  }
  
  async sendMessage(event) {
    if (event) event.preventDefault()
    
    console.log('Send message called, selected customer:', this.selectedCustomerId)
    
    if (!this.selectedCustomerId) {
      this.showSendError("Please select a customer first")
      return
    }
    
    const content = this.messageInputTarget.value.trim()
    console.log('Message content:', content)
    
    if (!content) {
      this.showSendError("Please enter a message")
      return
    }
    
    this.isSending = true
    this.showSendingIndicator()
    this.hideSendError()
    
    try {
      const url = `${this.apiBaseUrlValue}/whatsapp/customer/${this.selectedCustomerId}/send_text`
      console.log('Sending to URL:', url)
      
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': this.getCSRFToken()
        },
        body: JSON.stringify({ content: content })
      })
      
      console.log('Send response status:', response.status)
      const data = await response.json()
      console.log('Send response data:', data)
      
      this.hideSendingIndicator()
      this.isSending = false
      
      if (!response.ok || !data.success) {
        this.showSendError(data.error || `Failed to send message (${response.status})`)
        return
      }
      
      console.log('Message sent successfully:', data)
      
      // Clear input
      this.messageInputTarget.value = ''
      
      // Refresh messages
      this.fetchCustomerMessages(this.selectedCustomerId)
      
    } catch (error) {
      console.error('Error sending message:', error)
      this.hideSendingIndicator()
      this.isSending = false
      this.showSendError("Failed to send message: " + error.message)
    }
  }
  
  showSendingIndicator() {
    this.sendButtonTarget.disabled = true
    this.sendingIndicatorTarget.classList.remove('hidden')
  }
  
  hideSendingIndicator() {
    this.sendButtonTarget.disabled = false
    this.sendingIndicatorTarget.classList.add('hidden')
  }
  
  showSendError(message) {
    this.sendErrorTarget.classList.remove('hidden')
    this.sendErrorMessageTarget.textContent = message
  }
  
  hideSendError() {
    this.sendErrorTarget.classList.add('hidden')
  }
  
  showError(message) {
    this.errorTarget.classList.remove('hidden')
    this.errorMessageTarget.textContent = message
  }
  
  showCustomerError(message) {
    if (this.hasCustomerErrorTarget) {
      this.customerErrorTarget.classList.remove('hidden')
      this.customerErrorMessageTarget.textContent = message
    }
  }
  
  getCSRFToken() {
    return document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
  }

  // === MULTIMEDIA FUNCTIONALITY ===
  
  setupDragAndDrop() {
    const messagesContainer = document.getElementById('messagesContainer')
    if (!messagesContainer) return
    
    // Prevent default drag behaviors
    ['dragenter', 'dragover', 'dragleave', 'drop'].forEach(eventName => {
      messagesContainer.addEventListener(eventName, this.preventDefaults.bind(this), false)
      document.body.addEventListener(eventName, this.preventDefaults.bind(this), false)
    })
    
    // Highlight drop area when item is dragged over it
    ['dragenter', 'dragover'].forEach(eventName => {
      messagesContainer.addEventListener(eventName, this.highlight.bind(this), false)
    })
    
    ['dragleave', 'drop'].forEach(eventName => {
      messagesContainer.addEventListener(eventName, this.unhighlight.bind(this), false)
    })
    
    // Handle dropped files
    messagesContainer.addEventListener('drop', this.handleDrop.bind(this), false)
  }
  
  preventDefaults(e) {
    e.preventDefault()
    e.stopPropagation()
  }
  
  highlight(e) {
    const messagesContainer = document.getElementById('messagesContainer')
    if (messagesContainer) {
      messagesContainer.classList.add('border-green-500', 'bg-green-50')
    }
  }
  
  unhighlight(e) {
    const messagesContainer = document.getElementById('messagesContainer')
    if (messagesContainer) {
      messagesContainer.classList.remove('border-green-500', 'bg-green-50')
    }
  }
  
  handleDrop(e) {
    const dt = e.dataTransfer
    const files = dt.files
    
    if (files.length > 0) {
      this.processFile(files[0])
    }
  }
  
  showAttachMenu() {
    this.fileInputTarget.click()
  }
  
  handleFileSelect(e) {
    const file = e.target.files[0]
    if (file) {
      this.processFile(file)
    }
  }
  
  processFile(file) {
    console.log('Processing file:', file)
    
    // Validate file
    if (!this.validateFile(file)) {
      return
    }
    
    this.selectedFile = file
    this.showMediaPreview(file)
  }
  
  validateFile(file) {
    const maxSize = 10 * 1024 * 1024 // 10MB as per CLAUDE.md
    
    if (file.size > maxSize) {
      this.showSendError(`File size too large. Maximum size allowed is 10MB. Your file is ${this.formatFileSize(file.size)}.`)
      return false
    }
    
    const allowedTypes = [
      // Images
      'image/jpeg', 'image/jpg', 'image/png', 'image/gif',
      // Videos  
      'video/mp4', 'video/3gpp', 'video/quicktime',
      // Audio
      'audio/mpeg', 'audio/wav', 'audio/ogg', 'audio/mp4',
      // Documents
      'application/pdf', 'application/msword', 
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'text/plain', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      'text/csv'
    ]
    
    if (!allowedTypes.includes(file.type)) {
      this.showSendError(`File type not supported. Supported types: Images, Videos, Audio, PDF, Word, Excel, Text, CSV.`)
      return false
    }
    
    return true
  }
  
  showMediaPreview(file) {
    // Update file name
    this.mediaFileNameTarget.textContent = file.name
    
    // Update file size
    this.mediaFileSizeTarget.textContent = this.formatFileSize(file.size)
    
    // Update preview icon based on file type
    this.updatePreviewIcon(file)
    
    // Clear caption
    this.mediaCaptionInputTarget.value = ''
    
    // Show preview
    this.mediaPreviewTarget.classList.remove('hidden')
    
    // Hide text message input temporarily
    this.messageInputTarget.disabled = true
    this.sendButtonTarget.disabled = true
  }
  
  updatePreviewIcon(file) {
    const iconContainer = this.mediaPreviewIconTarget
    
    if (file.type.startsWith('image/')) {
      // Show image preview
      const reader = new FileReader()
      reader.onload = (e) => {
        iconContainer.innerHTML = `<img src="${e.target.result}" class="w-full h-full object-cover rounded-lg" alt="Preview">`
      }
      reader.readAsDataURL(file)
    } else if (file.type.startsWith('video/')) {
      iconContainer.innerHTML = '<i class="fas fa-video text-red-500 text-xl"></i>'
    } else if (file.type.startsWith('audio/')) {
      iconContainer.innerHTML = '<i class="fas fa-music text-purple-500 text-xl"></i>'
    } else if (file.type === 'application/pdf') {
      iconContainer.innerHTML = '<i class="fas fa-file-pdf text-red-500 text-xl"></i>'
    } else if (file.type.includes('word')) {
      iconContainer.innerHTML = '<i class="fas fa-file-word text-blue-500 text-xl"></i>'
    } else if (file.type.includes('sheet') || file.type.includes('excel')) {
      iconContainer.innerHTML = '<i class="fas fa-file-excel text-green-500 text-xl"></i>'
    } else {
      iconContainer.innerHTML = '<i class="fas fa-file text-gray-500 text-xl"></i>'
    }
  }
  
  removeMedia() {
    this.selectedFile = null
    this.mediaPreviewTarget.classList.add('hidden')
    
    // Re-enable text message input
    this.messageInputTarget.disabled = false
    this.sendButtonTarget.disabled = false
    
    // Clear file input
    this.fileInputTarget.value = ''
  }
  
  async sendMediaMessage() {
    if (!this.selectedCustomerId) {
      this.showSendError("Please select a customer first")
      return
    }
    
    if (!this.selectedFile) {
      this.showSendError("No file selected")
      return
    }
    
    const caption = this.mediaCaptionInputTarget.value.trim()
    
    console.log('Sending media file:', this.selectedFile.name, 'with caption:', caption)
    
    // Disable send button
    this.sendMediaButtonTarget.disabled = true
    this.sendMediaButtonTarget.innerHTML = '<i class="fas fa-spinner fa-spin mr-2"></i>Sending...'
    
    try {
      // Convert file to base64
      const base64Data = await this.fileToBase64(this.selectedFile)
      
      const url = `${this.apiBaseUrlValue}/whatsapp/customer/${this.selectedCustomerId}/send_image`
      console.log('Sending media to URL:', url)
      
      const formData = new FormData()
      formData.append('file', this.selectedFile)
      if (caption) {
        formData.append('caption', caption)
      }
      
      const response = await fetch(url, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': this.getCSRFToken()
        },
        body: formData
      })
      
      console.log('Media send response status:', response.status)
      const data = await response.json()
      console.log('Media send response data:', data)
      
      if (!response.ok || !data.success) {
        this.showSendError(data.error || `Failed to send media (${response.status})`)
        return
      }
      
      console.log('Media sent successfully:', data)
      
      // Clear media preview
      this.removeMedia()
      
      // Refresh messages
      this.fetchCustomerMessages(this.selectedCustomerId)
      
    } catch (error) {
      console.error('Error sending media:', error)
      this.showSendError("Failed to send media: " + error.message)
    } finally {
      // Re-enable send button
      this.sendMediaButtonTarget.disabled = false
      this.sendMediaButtonTarget.innerHTML = '<i class="fas fa-paper-plane mr-2"></i>Send Media'
    }
  }
  
  fileToBase64(file) {
    return new Promise((resolve, reject) => {
      const reader = new FileReader()
      reader.readAsDataURL(file)
      reader.onload = () => {
        const base64String = reader.result.split(',')[1] // Remove data:image/jpeg;base64, prefix
        resolve(base64String)
      }
      reader.onerror = error => reject(error)
    })
  }
  
  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes'
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }
}