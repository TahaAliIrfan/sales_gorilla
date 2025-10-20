import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messagesContainer", "messagesArea", "messageInput", "sendButton", 
                   "messageForm", "fileForm", "fileInput", "filePreview", "fileName", 
                   "fileSize", "fileIcon", "fileCaption", "fileSendButton", "statusMessage",
                   "chatList", "chatArea", "chatHeader", "contactName", "contactInfo", 
                   "contactAvatar", "viewCustomerBtn", "messageInputArea", "placeholder"]

  connect() {
    console.log("TecaudexChat controller connected")
    console.log("Available targets:", this.targets)
    console.log("Messages area target:", this.messagesAreaTarget)
    console.log("Chat header target:", this.chatHeaderTarget)
    console.log("Message input area target:", this.messageInputAreaTarget)
    this.selectedFile = null
    this.currentChatId = null
    this.currentCustomerId = null
  }

  // Select a chat from the sidebar
  selectChat(event) {
    const chatElement = event.currentTarget
    const chatId = chatElement.dataset.chatId
    
    if (this.currentChatId === chatId) {
      return // Already selected
    }

    // Update UI to show selected state
    this.updateChatSelection(chatElement)
    
    // Load the chat
    this.loadChat(chatId)
  }

  updateChatSelection(selectedElement) {
    // Remove active class from all chat items
    this.chatListTarget.querySelectorAll('.chat-item').forEach(item => {
      item.classList.remove('active')
    })
    
    // Add active class to selected item
    selectedElement.classList.add('active')
  }

  loadChat(chatId) {
    this.currentChatId = chatId
    this.showLoadingState()

    console.log("Loading chat:", chatId)
    const url = `/tecaudex_chat/${encodeURIComponent(chatId)}/load_chat`
    console.log("Request URL:", url)

    fetch(url, {
      method: "GET",
      headers: {
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector('[name="csrf-token"]').content
      }
    })
    .then(response => {
      console.log("Response status:", response.status)
      console.log("Response headers:", response.headers)
      
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`)
      }
      return response.json()
    })
    .then(data => {
      console.log("Response data:", data)
      console.log("Messages count:", data.messages ? data.messages.length : 'No messages')
      if (data.success) {
        this.showChatArea(data)
      } else {
        console.error("Load chat failed:", data.error)
        this.showStatus(`Error loading chat: ${data.error}`, "error")
      }
    })
    .catch(error => {
      console.error("Error loading chat:", error)
      this.showStatus(`Failed to load chat: ${error.message}`, "error")
    })
  }

  showChatArea(data) {
    console.log("showChatArea called with:", data)
    console.log("All targets exist?", {
      placeholder: this.hasPlaceholderTarget,
      chatHeader: this.hasChatHeaderTarget,
      contactName: this.hasContactNameTarget,
      contactInfo: this.hasContactInfoTarget,
      contactAvatar: this.hasContactAvatarTarget,
      messagesArea: this.hasMessagesAreaTarget,
      messageInputArea: this.hasMessageInputAreaTarget
    })
    
    // Hide placeholder
    if (this.hasPlaceholderTarget) {
      console.log("Hiding placeholder")
      this.placeholderTarget.classList.add('hidden')
    }
    
    // Show and update chat header
    if (this.hasChatHeaderTarget) {
      console.log("Showing chat header")
      this.chatHeaderTarget.classList.remove('hidden')
      
      if (this.hasContactNameTarget) {
        this.contactNameTarget.textContent = data.contact_name
      }
      if (this.hasContactInfoTarget) {
        this.contactInfoTarget.textContent = data.contact_info  
      }
      if (this.hasContactAvatarTarget) {
        this.contactAvatarTarget.textContent = data.contact_avatar
      }
    }
    
    // Show/hide view customer button
    if (this.hasViewCustomerBtnTarget) {
      if (data.customer_id) {
        this.currentCustomerId = data.customer_id
        this.viewCustomerBtnTarget.classList.remove('hidden')
        this.viewCustomerBtnTarget.onclick = () => {
          window.open(`/customers/${data.customer_id}`, '_blank')
        }
      } else {
        this.currentCustomerId = null
        this.viewCustomerBtnTarget.classList.add('hidden')
      }
    }
    
    // Render messages from JSON data
    console.log("Rendering messages:", data.messages)
    this.renderMessages(data.messages)
    
    // Show message input area
    if (this.hasMessageInputAreaTarget) {
      console.log("Showing message input area")
      this.messageInputAreaTarget.classList.remove('hidden')
    }
    
    // Scroll to bottom
    this.scrollToBottom()
  }

  renderMessages(messages) {
    console.log("renderMessages called with:", messages)
    console.log("Messages area target:", this.messagesAreaTarget)
    
    if (!messages || messages.length === 0) {
      console.log("No messages, showing empty state")
      this.messagesAreaTarget.innerHTML = `
        <div class="flex justify-center items-center py-8 min-h-[400px]">
          <div class="text-center">
            <svg class="h-12 w-12 text-gray-400 mx-auto mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/>
            </svg>
            <p class="text-gray-500 text-sm">No messages yet</p>
            <p class="text-gray-400 text-xs mt-1">Start the conversation by sending a message</p>
          </div>
        </div>
      `
      return
    }

    console.log("Rendering", messages.length, "messages")
    const messagesHtml = messages.map(message => this.renderSingleMessage(message)).join('')
    console.log("Generated HTML length:", messagesHtml.length)
    this.messagesAreaTarget.innerHTML = `<div class="space-y-4 pb-4">${messagesHtml}</div>`
    console.log("Messages rendered, final HTML:", this.messagesAreaTarget.innerHTML.substring(0, 200) + "...")
  }

  renderSingleMessage(message) {
    const isInbound = message.direction === 'inbound'
    const tempAttr = message.is_temporary ? 'data-temp="true"' : ''
    const opacity = message.status === 'sending' ? 'opacity-70 status-sending' : ''
    
    if (isInbound) {
      return `
        <div class="message-item" ${tempAttr}>
          <div class="flex items-start space-x-3 ${opacity}">
            <div class="flex-shrink-0">
              <div class="h-8 w-8 bg-gray-300 rounded-full flex items-center justify-center">
                <span class="text-xs font-medium text-gray-700">${message.customer_name}</span>
              </div>
            </div>
            <div class="flex-1 min-w-0">
              <div class="bg-gray-100 rounded-lg px-3 py-2 max-w-xs">
                <div class="text-sm text-gray-900">
                  ${this.renderMessageContent(message)}
                </div>
              </div>
              <div class="text-xs text-gray-500 mt-1">
                ${message.created_at}${message.status ? ' • ' + this.humanizeStatus(message.status) : ''}
              </div>
            </div>
          </div>
        </div>
      `
    } else {
      return `
        <div class="message-item" ${tempAttr}>
          <div class="flex items-start justify-end space-x-3 ${opacity}">
            <div class="flex-1 min-w-0 flex justify-end">
              <div class="bg-red-500 text-white rounded-lg px-3 py-2 max-w-xs">
                <div class="text-sm">
                  ${this.renderMessageContent(message)}
                </div>
              </div>
            </div>
            <div class="flex-shrink-0">
              <div class="h-8 w-8 bg-red-500 rounded-full flex items-center justify-center">
                <span class="text-xs font-medium text-white">You</span>
              </div>
            </div>
          </div>
          <div class="text-xs text-gray-500 mt-1 text-right">
            ${message.created_at}${message.status ? ' • ' + this.humanizeStatus(message.status) : ''}
            ${message.status === 'sending' ? '<span class="ml-1">⏳</span>' : ''}
          </div>
        </div>
      `
    }
  }

  renderMessageContent(message) {
    if (message.message_type === 'text') {
      return this.escapeHtml(message.content).replace(/\n/g, '<br>')
    } else if (message.has_attachment) {
      let content = ''
      
      // Add attachment icon and download link
      const iconHtml = this.getAttachmentIcon(message.message_type)
      content += `
        <div class="flex items-center space-x-2">
          ${iconHtml}
          <a href="${message.attachment_url}" target="_blank" class="${message.direction === 'inbound' ? 'text-blue-600 hover:text-blue-800' : 'text-white'} underline">
            ${message.attachment_filename || 'Download'}
          </a>
        </div>
      `
      
      // Show image preview if it's an image
      if (message.is_image && message.image_url) {
        content += `
          <div class="mt-2">
            <img src="${message.image_url}" class="max-w-48 h-auto rounded-md border ${message.direction === 'inbound' ? 'border-gray-200' : 'border-red-300'}" loading="lazy" />
          </div>
        `
      }
      
      return content
    } else {
      return `<em class="${message.direction === 'inbound' ? 'text-gray-500' : 'text-red-100'}">${this.escapeHtml(message.content)}</em>`
    }
  }

  getAttachmentIcon(messageType) {
    const iconClass = "h-5 w-5"
    
    switch (messageType) {
      case 'image':
        return `<svg class="${iconClass} text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
        </svg>`
      case 'document':
        return `<svg class="${iconClass} text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
        </svg>`
      case 'audio':
        return `<svg class="${iconClass} text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.686 9l3-3m0 0l3 3m-3-3v12"/>
        </svg>`
      case 'video':
        return `<svg class="${iconClass} text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
        </svg>`
      default:
        return `<svg class="${iconClass} text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13"/>
        </svg>`
    }
  }

  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  humanizeStatus(status) {
    return status.charAt(0).toUpperCase() + status.slice(1).replace('_', ' ')
  }

  renderChatList(chats) {
    if (!chats || chats.length === 0) {
      this.chatListTarget.innerHTML = `
        <div class="flex flex-col items-center justify-center h-64 text-center">
          <svg class="h-16 w-16 text-gray-300 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z"/>
          </svg>
          <h3 class="text-lg font-medium text-gray-900 mb-2">No chats available</h3>
          <p class="text-gray-500">No WhatsApp chats found.</p>
          <button 
            data-action="click->tecaudex-chat#refreshChatList"
            class="mt-4 inline-flex items-center px-4 py-2 border border-transparent text-sm font-medium rounded-md text-white bg-red-600 hover:bg-red-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-red-500"
          >
            <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15"/>
            </svg>
            Retry
          </button>
        </div>
      `
      return
    }

    const chatsHtml = chats.map(chat => this.renderSingleChat(chat)).join('')
    this.chatListTarget.innerHTML = chatsHtml
  }

  renderSingleChat(chat) {
    const timeString = chat.timestamp ? new Date(chat.timestamp * 1000).toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: false }) : ''
    
    return `
      <div class="chat-item border-b border-gray-100 hover:bg-red-50 cursor-pointer transition-colors" 
           data-action="click->tecaudex-chat#selectChat"
           data-chat-id="${chat.id}"
           data-chat-name="${chat.name.toLowerCase()}">
        <div class="p-4">
          <div class="flex items-center justify-between">
            <div class="flex items-center space-x-3 flex-1 min-w-0">
              <!-- Contact Avatar -->
              <div class="flex-shrink-0">
                <div class="h-12 w-12 bg-red-100 rounded-full flex items-center justify-center">
                  <span class="text-red-600 font-medium text-lg">${chat.avatar}</span>
                </div>
              </div>
              
              <!-- Contact Info -->
              <div class="flex-1 min-w-0">
                <div class="flex items-center justify-between">
                  <h3 class="text-sm font-medium text-gray-900 truncate">${this.escapeHtml(chat.name)}</h3>
                  <div class="flex items-center space-x-2">
                    ${chat.unread_count > 0 ? `
                      <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-red-100 text-red-800">
                        ${chat.unread_count}
                      </span>
                    ` : ''}
                    <span class="text-xs text-gray-500">${timeString}</span>
                  </div>
                </div>
                
                <!-- Customer Info -->
                <p class="text-xs ${chat.is_customer ? 'text-blue-600' : 'text-gray-400'} truncate">
                  ${this.escapeHtml(chat.customer_info)}
                </p>
                
                <!-- Last Message Preview -->
                ${chat.last_message ? `
                  <div class="mt-1 flex items-center">
                    ${chat.last_message.fromMe ? `
                      <svg class="h-3 w-3 text-gray-400 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"/>
                      </svg>
                    ` : ''}
                    <p class="text-sm text-gray-500 truncate">
                      ${chat.last_message.body ? this.escapeHtml(this.truncateText(chat.last_message.body, 50)) : `<em>${chat.last_message.type ? chat.last_message.type.charAt(0).toUpperCase() + chat.last_message.type.slice(1) : 'Media'}</em>`}
                    </p>
                  </div>
                ` : `
                  <p class="mt-1 text-sm text-gray-400">No messages</p>
                `}
              </div>
            </div>
          </div>
        </div>
      </div>
    `
  }

  truncateText(text, length) {
    return text.length > length ? text.substring(0, length) + '...' : text
  }

  showLoadingState() {
    this.messagesAreaTarget.innerHTML = `
      <div class="flex justify-center items-center py-8">
        <div class="text-gray-500 text-sm">Loading messages...</div>
      </div>
    `
  }

  // Filter chats in the sidebar
  filterChats(event) {
    const searchTerm = event.target.value.toLowerCase()
    const chatItems = this.chatListTarget.querySelectorAll('.chat-item')
    
    chatItems.forEach(item => {
      const chatName = item.dataset.chatName || ''
      if (chatName.includes(searchTerm)) {
        item.style.display = 'block'
      } else {
        item.style.display = 'none'
      }
    })
  }

  // Refresh chat list
  refreshChatList() {
    fetch('/tecaudex_chat/refresh_chat_list', {
      method: "GET",
      headers: {
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector('[name="csrf-token"]').content
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        this.renderChatList(data.chats)
        this.showStatus("Chat list refreshed", "success")
      } else {
        this.showStatus(`Error: ${data.error}`, "error")
      }
    })
    .catch(error => {
      console.error("Error refreshing chat list:", error)
      this.showStatus("Failed to refresh chat list", "error")
    })
  }

  // Handle message sending
  sendMessage(event) {
    event.preventDefault()
    
    if (!this.currentChatId) {
      this.showStatus("Please select a chat first", "error")
      return
    }
    
    const messageContent = this.messageInputTarget.value.trim()
    if (!messageContent) return

    // Immediately show the message as "sending"
    this.addTemporaryMessage(messageContent, 'outbound', 'sending')
    
    this.messageInputTarget.value = ""
    this.scrollToBottom()
    this.disableForm()

    const formData = new FormData()
    formData.append("message_content", messageContent)

    fetch(`/tecaudex_chat/${encodeURIComponent(this.currentChatId)}/send_message`, {
      method: "POST",
      body: formData,
      headers: {
        "X-CSRF-Token": document.querySelector('[name="csrf-token"]').content,
        "Accept": "application/json"
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        this.showStatus("Message sent", "success")
        // Refresh to get the actual message with proper ID and status
        setTimeout(() => this.refreshMessages(), 500)
      } else {
        this.showStatus(`Error: ${data.error}`, "error")
        // Remove the temporary message on error
        this.removeTemporaryMessage()
      }
    })
    .catch(error => {
      console.error("Error sending message:", error)
      this.showStatus("Failed to send message", "error")
      this.removeTemporaryMessage()
    })
    .finally(() => {
      this.enableForm()
    })
  }

  addTemporaryMessage(content, direction, status = 'sending') {
    const tempMessage = {
      id: 'temp-' + Date.now(),
      content: content,
      message_type: 'text',
      direction: direction,
      created_at: new Date().toLocaleTimeString('en-US', { hour: '2-digit', minute: '2-digit', hour12: false }),
      status: status,
      customer_name: 'You',
      has_attachment: false,
      is_temporary: true
    }

    const messageHtml = this.renderSingleMessage(tempMessage)
    
    // Add to messages area
    if (this.hasMessagesAreaTarget) {
      const messagesContainer = this.messagesAreaTarget.querySelector('.space-y-4') || this.messagesAreaTarget
      messagesContainer.insertAdjacentHTML('beforeend', messageHtml)
      
      // Scroll to bottom after adding the message
      this.scrollToBottom()
    }
  }

  removeTemporaryMessage() {
    // Remove any temporary messages
    const tempMessages = this.messagesAreaTarget.querySelectorAll('[data-temp="true"]')
    tempMessages.forEach(msg => msg.remove())
  }

  // Handle file upload
  openFileDialog() {
    this.fileInputTarget.click()
  }

  handleFileSelect(event) {
    const file = event.target.files[0]
    if (!file) return

    this.selectedFile = file
    this.showFilePreview(file)
  }

  showFilePreview(file) {
    this.fileNameTarget.textContent = file.name
    this.fileSizeTarget.textContent = this.formatFileSize(file.size)
    
    // Set file icon based on type
    this.fileIconTarget.innerHTML = this.getFileIcon(file.type)
    
    this.filePreviewTarget.classList.remove("hidden")
  }

  sendFile(event) {
    event.preventDefault()
    
    if (!this.currentChatId) {
      this.showStatus("Please select a chat first", "error")
      return
    }
    
    if (!this.selectedFile) return

    const caption = this.fileCaptionTarget.value.trim()
    
    this.showStatus("Uploading file...", "info")
    this.disableFileForm()

    const formData = new FormData()
    formData.append("file", this.selectedFile)
    if (caption) {
      formData.append("caption", caption)
    }

    fetch(`/tecaudex_chat/${encodeURIComponent(this.currentChatId)}/send_media`, {
      method: "POST", 
      body: formData,
      headers: {
        "X-CSRF-Token": document.querySelector('[name="csrf-token"]').content,
        "Accept": "application/json"
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        this.showStatus("File sent successfully", "success")
        this.cancelFile()
        this.refreshMessages()
      } else {
        this.showStatus(`Error: ${data.error}`, "error")
      }
    })
    .catch(error => {
      console.error("Error sending file:", error)
      this.showStatus("Failed to send file", "error")
    })
    .finally(() => {
      this.enableFileForm()
    })
  }

  cancelFile() {
    this.selectedFile = null
    this.fileInputTarget.value = ""
    this.fileCaptionTarget.value = ""
    this.filePreviewTarget.classList.add("hidden")
  }

  // Refresh messages
  refreshMessages() {
    if (!this.currentChatId) {
      this.showStatus("No chat selected", "error")
      return
    }

    fetch(`/tecaudex_chat/${encodeURIComponent(this.currentChatId)}/refresh_messages`, {
      method: "GET",
      headers: {
        "Accept": "application/json",
        "X-CSRF-Token": document.querySelector('[name="csrf-token"]').content
      }
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        this.renderMessages(data.messages)
        this.scrollToBottom()
      } else {
        this.showStatus(`Error refreshing: ${data.error}`, "error")
      }
    })
    .catch(error => {
      console.error("Error refreshing messages:", error)
      this.showStatus("Failed to refresh messages", "error")
    })
  }

  // Handle keyboard shortcuts
  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.sendMessage(event)
    }
  }

  // Utility methods
  scrollToBottom() {
    if (this.hasMessagesContainerTarget) {
      // Use requestAnimationFrame for smooth scrolling
      requestAnimationFrame(() => {
        this.messagesContainerTarget.scrollTop = this.messagesContainerTarget.scrollHeight
      })
    }
  }

  showStatus(message, type) {
    const statusElement = this.statusMessageTarget
    statusElement.textContent = message
    statusElement.className = `mt-2 text-sm ${this.getStatusClass(type)}`
    statusElement.classList.remove("hidden")
    
    setTimeout(() => {
      statusElement.classList.add("hidden")
    }, 3000)
  }

  getStatusClass(type) {
    switch (type) {
      case "success": return "text-green-600"
      case "error": return "text-red-600"
      case "info": return "text-blue-600"
      default: return "text-gray-600"
    }
  }

  disableForm() {
    this.messageInputTarget.disabled = true
    this.sendButtonTarget.disabled = true
  }

  enableForm() {
    this.messageInputTarget.disabled = false
    this.sendButtonTarget.disabled = false
  }

  disableFileForm() {
    this.fileSendButtonTarget.disabled = true
  }

  enableFileForm() {
    this.fileSendButtonTarget.disabled = false
  }

  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes'
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }

  getFileIcon(mimeType) {
    if (mimeType.startsWith('image/')) {
      return `<div class="h-8 w-8 bg-green-100 rounded-lg flex items-center justify-center">
                <svg class="h-5 w-5 text-green-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z"/>
                </svg>
              </div>`
    } else if (mimeType.includes('pdf')) {
      return `<div class="h-8 w-8 bg-red-100 rounded-lg flex items-center justify-center">
                <svg class="h-5 w-5 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                </svg>
              </div>`
    } else if (mimeType.startsWith('audio/')) {
      return `<div class="h-8 w-8 bg-purple-100 rounded-lg flex items-center justify-center">
                <svg class="h-5 w-5 text-purple-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.686 9l3-3m0 0l3 3m-3-3v12"/>
                </svg>
              </div>`
    } else if (mimeType.startsWith('video/')) {
      return `<div class="h-8 w-8 bg-orange-100 rounded-lg flex items-center justify-center">
                <svg class="h-5 w-5 text-orange-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z"/>
                </svg>
              </div>`
    } else {
      return `<div class="h-8 w-8 bg-gray-100 rounded-lg flex items-center justify-center">
                <svg class="h-5 w-5 text-gray-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
                </svg>
              </div>`
    }
  }
}