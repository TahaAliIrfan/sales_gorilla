import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messages", "messageContainer", "loader", "noMessages", "error", "errorMessage"]
  static values = { url: String }

  connect() {
    if (this.hasUrlValue) {
      this.fetchMessages()
    }
  }

  fetchMessages() {
    fetch(this.urlValue)
      .then(response => response.json())
      .then(data => {
        this.loaderTarget.classList.add('hidden')
        
        if (!data.success) {
          this.showError(data.error || "Failed to load WhatsApp messages")
          return
        }
        
        if (!data.data || !data.data.data || data.data.data.length === 0) {
          this.noMessagesTarget.classList.remove('hidden')
          return
        }
        
        // Process and display the messages
        this.displayMessages(data.data.data)
      })
      .catch(error => {
        console.error("Error fetching WhatsApp messages:", error)
        this.showError("An error occurred while loading messages.")
        this.loaderTarget.classList.add('hidden')
      })
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
    sortedMessages.forEach(item => {
      if (!item.message || !item.message._data) return
      
      const messageData = item.message
      const data = messageData._data
      
      // Skip system messages or messages without content
      if (data.type === "e2e_notification" || !messageData.body) return
      
      const isFromMe = data.fromMe
      const messageBody = messageData.body || "No content"
      const timestamp = data.t ? new Date(data.t * 1000).toLocaleString() : "Unknown time"
      
      // Create message element
      const messageElement = document.createElement('div')
      messageElement.className = isFromMe 
        ? 'flex justify-end' 
        : 'flex justify-start'
        
      messageElement.innerHTML = `
        <div class="${isFromMe ? 'bg-green-100 text-green-800' : 'bg-gray-100 text-gray-800'} rounded-lg px-4 py-2 max-w-xs sm:max-w-md">
          <p class="text-sm">${messageBody}</p>
          <p class="text-xs text-gray-500 mt-1 text-right">${timestamp}</p>
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