import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messages", "messageContainer", "loader", "noMessages", "error", "errorMessage", "refreshButton"]
  static values = { url: String, systemNumber: String }

  connect() {
    if (this.hasUrlValue) {
      // Set default system number if not provided
      if (!this.hasSystemNumberValue) {
        this.systemNumberValue = "923004018239"
      }
      console.log(`WhatsApp Chat: System number is ${this.systemNumberValue}`)
      this.fetchMessages()
    }
  }

  fetchMessages(forceRefresh = false) {
    // Show loader
    this.loaderTarget.classList.remove('hidden')
    
    // Hide other content
    this.noMessagesTarget.classList.add('hidden')
    this.errorTarget.classList.add('hidden')
    
    // Disable refresh button during load
    if (this.hasRefreshButtonTarget) {
      this.refreshButtonTarget.disabled = true
    }
    
    // Build URL with refresh parameter if needed
    const url = forceRefresh ? 
      `${this.urlValue}?force_refresh=true` : 
      this.urlValue
      
    fetch(url)
      .then(response => response.json())
      .then(data => {
        this.loaderTarget.classList.add('hidden')
        
        // Re-enable refresh button
        if (this.hasRefreshButtonTarget) {
          this.refreshButtonTarget.disabled = false
        }
        
        if (!data.success) {
          this.showError(data.error || "Failed to load WhatsApp messages")
          return
        }
        
        if (!data.data || !data.data.data || data.data.data.length === 0) {
          this.noMessagesTarget.classList.remove('hidden')
          return
        }
        
        console.log("WhatsApp Messages received:", data.data.data)
        
        // Process and display the messages
        this.displayMessages(data.data.data)
      })
      .catch(error => {
        console.error("Error fetching WhatsApp messages:", error)
        this.showError("An error occurred while loading messages.")
        this.loaderTarget.classList.add('hidden')
        
        // Re-enable refresh button
        if (this.hasRefreshButtonTarget) {
          this.refreshButtonTarget.disabled = false
        }
      })
  }
  
  refresh(event) {
    event.preventDefault()
    this.fetchMessages(true)
  }
  
  displayMessages(messages) {
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
    
    // Scroll to the bottom of the messages
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }
  
  showError(message) {
    this.errorTarget.classList.remove('hidden')
    this.errorMessageTarget.textContent = message
  }
} 