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
    "textRadio",
    "mediaRadio",
    "mediaInputs",
    "mediaUrl",
    "mediaCaption",
    "mediaType",
    "sendingIndicator",
    "sendError",
    "sendErrorMessage",
    "messageForm"
  ]
  static values = { 
    url: String, 
    systemNumber: String 
  }

  connect() {
    if (this.hasUrlValue) {
      // Set default system number if not provided
      if (!this.hasSystemNumberValue) {
        this.systemNumberValue = "923004018239"
      }
      console.log(`WhatsApp Chat: System number is ${this.systemNumberValue}`)
      
      // Initial fetch
      this.fetchMessages()
      
      // Set up auto-refresh every 5 seconds
      this.startAutoRefresh()
    }
  }
  
  disconnect() {
    // Clean up the interval when the controller disconnects
    this.stopAutoRefresh()
  }
  
  startAutoRefresh() {
    // Clear any existing interval first
    this.stopAutoRefresh()
    
    // Set new interval (5000ms = 5 seconds)
    this.refreshInterval = setInterval(() => {
      // Only refresh if not currently sending a message
      if (!this.isSending) {
        this.fetchMessages(false, true)
      }
    }, 5000)
    
    console.log("WhatsApp Chat: Auto-refresh started")
  }
  
  stopAutoRefresh() {
    if (this.refreshInterval) {
      clearInterval(this.refreshInterval)
      this.refreshInterval = null
      console.log("WhatsApp Chat: Auto-refresh stopped")
    }
  }

  fetchMessages(forceRefresh = false, isAutoRefresh = false) {
    // If this is an auto-refresh, don't show the loader
    if (!isAutoRefresh) {
      // Show loader
      this.loaderTarget.classList.remove('hidden')
      
      // Hide other content
      this.noMessagesTarget.classList.add('hidden')
      this.errorTarget.classList.add('hidden')
      
      // Disable refresh button during load
      if (this.hasRefreshButtonTarget) {
        this.refreshButtonTarget.disabled = true
      }
    }
    
    // Build URL with refresh parameter if needed
    const url = forceRefresh ? 
      `${this.urlValue}?force_refresh=true` : 
      this.urlValue
      
    fetch(url)
      .then(response => response.json())
      .then(data => {
        // If this isn't an auto-refresh, show/hide the loader
        if (!isAutoRefresh) {
          this.loaderTarget.classList.add('hidden')
          
          // Re-enable refresh button
          if (this.hasRefreshButtonTarget) {
            this.refreshButtonTarget.disabled = false
          }
        }
        
        if (!data.success) {
          if (!isAutoRefresh) {
            this.showError(data.error || "Failed to load WhatsApp messages")
          }
          return
        }
        
        if (!data.data || !data.data.data || data.data.data.length === 0) {
          if (!isAutoRefresh) {
            this.noMessagesTarget.classList.remove('hidden')
          }
          return
        }
        
        if (!isAutoRefresh) {
          console.log("WhatsApp Messages received:", data.data.data)
        }
        
        // Process and display the messages
        this.displayMessages(data.data.data)
      })
      .catch(error => {
        // Only show errors for manual refreshes
        if (!isAutoRefresh) {
          console.error("Error fetching WhatsApp messages:", error)
          this.showError("An error occurred while loading messages.")
          this.loaderTarget.classList.add('hidden')
          
          // Re-enable refresh button
          if (this.hasRefreshButtonTarget) {
            this.refreshButtonTarget.disabled = false
          }
        }
      })
  }
  
  refresh(event) {
    event.preventDefault()
    this.fetchMessages(true)
  }
  
  displayMessages(messages) {
    // Store scrollTop and scrollHeight to check if we were at the bottom
    const messagesElement = this.messagesTarget
    const wasAtBottom = messagesElement.scrollTop + messagesElement.clientHeight >= messagesElement.scrollHeight - 20
    
    // Clear the container
    this.messageContainerTarget.innerHTML = ""
    
    // Sort messages by timestamp if available
    const sortedMessages = messages.sort((a, b) => {
      if (a.message && a.message._data && b.message && b.message._data) {
        return a.message._data.t - b.message._data.t
      }
      return 0
    })
    
    // If no messages after filtering, show no messages message
    if (sortedMessages.length === 0) {
      this.noMessagesTarget.classList.remove('hidden')
      return
    }
    
    // Format and display each message
    sortedMessages.forEach((item, index) => {
      if (!item.message || !item.message._data) return
      
      const messageData = item.message
      const data = messageData._data
      
      // Skip system messages or messages without content
      if (data.type === "e2e_notification" || !messageData.body) return
      
      // Extract from and to information for debugging
      const fromInfo = data.from ? `${data.from.user}@${data.from.server}` : 'unknown'
      const toInfo = data.to ? `${data.to.user}@${data.to.server}` : 'unknown'
      
      console.log(`Message ${index}: From=${fromInfo}, To=${toInfo}, Body=${messageData.body.substring(0, 30)}...`)
      
      // Determine if message is from the system
      let isFromSystem = false
      
      // Better logic for determining message direction
      if (data.from && data.from.user) {
        // It's from our system if our number is in the "from" field
        isFromSystem = data.from.user === this.systemNumberValue.replace('+', '')
      } 
      
      if (data.fromMe) {
        // fromMe is the most reliable indicator
        isFromSystem = true
      }
      
      console.log(`Message ${index} is ${isFromSystem ? 'from SYSTEM' : 'from CUSTOMER'}`)
      
      const messageBody = messageData.body || "No content"
      const timestamp = data.t ? new Date(data.t * 1000).toLocaleString() : "Unknown time"
      
      // Get sender information
      const senderInfo = isFromSystem ? 
        { name: "Support Agent", icon: "user-tie" } : 
        { name: "Customer", icon: "user" }
      
      // Create message element
      const messageElement = document.createElement('div')
      messageElement.className = isFromSystem 
        ? 'flex flex-col items-end mb-4' 
        : 'flex flex-col items-start mb-4'
        
      messageElement.innerHTML = `
        <div class="flex items-end ${isFromSystem ? 'flex-row-reverse' : ''}">
          <div class="flex-shrink-0 h-8 w-8 rounded-full bg-${isFromSystem ? 'blue' : 'green'}-500 flex items-center justify-center">
            <i class="fas fa-${senderInfo.icon} text-white text-sm"></i>
          </div>
          <div class="${isFromSystem ? 'mr-2' : 'ml-2'} ${isFromSystem ? 'bg-blue-100 text-blue-800' : 'bg-green-100 text-green-800'} px-4 py-2 rounded-lg max-w-xs sm:max-w-md shadow-sm">
            <div class="text-xs text-${isFromSystem ? 'blue' : 'green'}-600 font-medium mb-1">${senderInfo.name}</div>
            <p class="text-sm">${messageBody}</p>
            <p class="text-xs text-gray-500 mt-1 text-right">${timestamp}</p>
          </div>
        </div>
      `
      
      this.messageContainerTarget.appendChild(messageElement)
    })
    
    // If user was at the bottom before refreshing, scroll to bottom again
    if (wasAtBottom) {
      this.scrollToBottom()
    }
  }
  
  scrollToBottom() {
    // Scroll to the bottom of the messages
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }
  
  toggleMessageType() {
    if (this.textRadioTarget.checked) {
      this.mediaInputsTarget.classList.add('hidden')
    } else {
      this.mediaInputsTarget.classList.remove('hidden')
    }
  }
  
  handleKeyPress(event) {
    // Send message when Enter is pressed (without Shift)
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault()
      this.sendMessage(event)
    }
  }
  
  sendMessage(event) {
    event.preventDefault()
    
    // Hide any previous errors
    this.sendErrorTarget.classList.add('hidden')
    
    // Check if it's a text or media message
    const isTextMessage = this.textRadioTarget.checked
    
    if (isTextMessage) {
      this.sendTextMessage()
    } else {
      this.sendMediaMessage()
    }
  }
  
  sendTextMessage() {
    const content = this.messageInputTarget.value.trim()
    
    if (!content) {
      this.showSendError("Please enter a message.")
      return
    }
    
    this.isSending = true
    this.showSendingIndicator()
    
    // Get the customer ID from the URL (assuming URL format: /customers/:id/whatsapp_messages)
    const customerId = this.getCustomerIdFromUrl()
    
    if (!customerId) {
      this.showSendError("Could not determine customer ID.")
      this.isSending = false
      return
    }
    
    // Send the text message
    fetch(`/customers/${customerId}/send_whatsapp_text`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.getCSRFToken()
      },
      body: JSON.stringify({ message: content })
    })
    .then(response => response.json())
    .then(data => {
      this.hideSendingIndicator()
      this.isSending = false
      
      if (!data.success) {
        this.showSendError(data.error || "Failed to send message")
        return
      }
      
      // Clear the input field
      this.messageInputTarget.value = ''
      
      // Refresh the messages to see the newly sent message
      this.fetchMessages(true)
    })
    .catch(error => {
      console.error("Error sending text message:", error)
      this.hideSendingIndicator()
      this.isSending = false
      this.showSendError("An error occurred while sending the message.")
    })
  }
  
  sendMediaMessage() {
    const mediaUrl = this.mediaUrlTarget.value.trim()
    const caption = this.mediaCaptionTarget.value.trim()
    const mediaType = this.mediaTypeTarget.value
    
    if (!mediaUrl) {
      this.showSendError("Please enter a media URL.")
      return
    }
    
    this.isSending = true
    this.showSendingIndicator()
    
    // Get the customer ID from the URL (assuming URL format: /customers/:id/whatsapp_messages)
    const customerId = this.getCustomerIdFromUrl()
    
    if (!customerId) {
      this.showSendError("Could not determine customer ID.")
      this.isSending = false
      return
    }
    
    // Send the media message
    fetch(`/customers/${customerId}/send_whatsapp_media`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.getCSRFToken()
      },
      body: JSON.stringify({ 
        media_url: mediaUrl,
        caption: caption,
        media_type: mediaType
      })
    })
    .then(response => response.json())
    .then(data => {
      this.hideSendingIndicator()
      this.isSending = false
      
      if (!data.success) {
        this.showSendError(data.error || "Failed to send media message")
        return
      }
      
      // Clear the input fields
      this.mediaUrlTarget.value = ''
      this.mediaCaptionTarget.value = ''
      
      // Refresh the messages to see the newly sent message
      this.fetchMessages(true)
    })
    .catch(error => {
      console.error("Error sending media message:", error)
      this.hideSendingIndicator()
      this.isSending = false
      this.showSendError("An error occurred while sending the media message.")
    })
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
    this.hideSendingIndicator()
  }
  
  showError(message) {
    this.errorTarget.classList.remove('hidden')
    this.errorMessageTarget.textContent = message
  }
  
  getCSRFToken() {
    return document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
  }
  
  getCustomerIdFromUrl() {
    // Extract customer ID from the URL or from a data attribute
    if (this.urlValue) {
      // Assuming URL format: /customers/:id/whatsapp_messages
      const match = this.urlValue.match(/\/customers\/(\d+)\/whatsapp_messages/)
      if (match && match[1]) {
        return match[1]
      }
    }
    
    return null
  }
} 