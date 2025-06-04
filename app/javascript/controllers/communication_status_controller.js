import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tag"]
  static values = {
    endpoint: String
  }
  
  connect() {
    console.log("Communication Status controller connected")
  }
  
  update(event) {
    const tag = event.currentTarget
    const statusType = tag.dataset.statusType
    const statusValue = tag.dataset.statusValue || tag.dataset.status
    const customerId = tag.dataset.customerId
    
    // Show a loading indicator
    tag.classList.add('opacity-50')
    
    // Get CSRF token
    const csrfToken = document.querySelector('meta[name="csrf-token"]')
    
    if (!csrfToken) {
      console.error('CSRF token not found')
      this.showNotification('CSRF token not found. Please refresh the page.', 'error')
      tag.classList.remove('opacity-50')
      return
    }
    
    console.log(`Sending request to update ${statusType || 'status'} to: ${statusValue}`)
    
    // Determine which endpoint to use
    const endpoint = statusType 
      ? `/customers/${customerId}/update_communication_status` 
      : `/customers/${customerId}/update_status`
      
    // Build request body
    const body = statusType 
      ? { status_type: statusType, status_value: statusValue }
      : { status: statusValue }
    
    // Send AJAX request to update status
    fetch(endpoint, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-CSRF-Token': csrfToken.content
      },
      body: JSON.stringify(body)
    })
    .then(response => {
      // Log the full response for debugging
      console.log('Response status:', response.status)
      
      // Check if response is ok before parsing JSON
      if (!response.ok) {
        console.error('Response not OK:', response.status, response.statusText)
        return response.text().then(text => {
          console.error('Error response text:', text)
          throw new Error(`Request failed with status ${response.status}: ${text}`)
        })
      }
      
      return response.json()
    })
    .then(data => {
      // Additional logging
      console.log('Response data:', data)
      
      if (data.success) {
        if (statusType) {
          this.updateCommunicationStatus(tag, statusType, statusValue)
        } else {
          this.updateMainStatus(tag, statusValue)
        }
        
        // Format the status type for display
        const formattedStatusType = statusType 
          ? statusType.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase())
          : 'Status'
        
        // Show success notification
        this.showNotification(`${formattedStatusType} updated to ${statusValue}`, 'success')
      } else {
        // Show error notification
        this.showNotification('Failed to update status', 'error')
      }
      
      // Remove loading indicator
      tag.classList.remove('opacity-50')
    })
    .catch(error => {
      console.error('Error:', error)
      
      // Show error notification
      this.showNotification('An error occurred while updating status', 'error')
      
      // Remove loading indicator
      tag.classList.remove('opacity-50')
    })
  }
  
  updateCommunicationStatus(tag, statusType, statusValue) {
    // Get all status tags for the current status type
    const relatedTags = document.querySelectorAll(`.comm-status-tag[data-status-type="${statusType}"]`)
    
    // Remove highlighting from all related tags
    relatedTags.forEach(t => {
      t.className = t.className.replace(/ring-2 ring-\w+-300/g, '')
      
      // Reset base colors based on status value
      const tagStatusValue = t.dataset.statusValue
      let baseClass = this.getBaseClass(statusType, tagStatusValue)
      
      t.className = `comm-status-tag inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium cursor-pointer transition-all duration-200 hover:shadow-md ${baseClass}`
    })
    
    // Add highlighting to the selected tag
    let activeClass = this.getActiveClass(statusType, statusValue)
    
    tag.className = `comm-status-tag inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium cursor-pointer transition-all duration-200 hover:shadow-md ${activeClass}`
  }
  
  updateMainStatus(tag, statusValue) {
    // Get all status tags
    const relatedTags = document.querySelectorAll('.status-tag')
    
    // Remove highlighting from all related tags
    relatedTags.forEach(t => {
      t.className = t.className.replace(/ring-2 ring-\w+-300/g, '')
      
      // Reset base colors based on status value
      const tagStatusValue = t.dataset.status
      let baseClass = this.getMainStatusBaseClass(tagStatusValue)
      
      t.className = `status-tag inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium cursor-pointer transition-all duration-200 hover:shadow-md ${baseClass}`
    })
    
    // Add highlighting to the selected tag
    let activeClass = this.getMainStatusActiveClass(statusValue)
    
    tag.className = `status-tag inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium cursor-pointer transition-all duration-200 hover:shadow-md ${activeClass}`
  }
  
  getMainStatusBaseClass(status) {
    switch (status) {
      case 'Contact Established': return 'bg-green-50 text-green-700'
      case 'Exhausted': return 'bg-red-50 text-red-700'
      case 'Pending': return 'bg-yellow-50 text-yellow-700'
      case 'Contact Not Established': return 'bg-red-50 text-red-700'
      case 'Unresponsive': return 'bg-orange-50 text-orange-700'
      case 'Converted': return 'bg-blue-50 text-blue-700'
      case 'Proposal Sent': return 'bg-indigo-50 text-indigo-700'
      case 'Not Interested': return 'bg-gray-50 text-gray-700'
      case 'Invalid': return 'bg-purple-50 text-purple-700'
      default: return 'bg-blue-50 text-blue-700'
    }
  }
  
  getMainStatusActiveClass(status) {
    switch (status) {
      case 'Contact Established': return 'bg-green-100 text-green-800 ring-2 ring-green-300'
      case 'Exhausted': return 'bg-red-100 text-red-800 ring-2 ring-red-300'
      case 'Pending': return 'bg-yellow-100 text-yellow-800 ring-2 ring-yellow-300'
      case 'Contact Not Established': return 'bg-red-100 text-red-800 ring-2 ring-red-300'
      case 'Unresponsive': return 'bg-orange-100 text-orange-800 ring-2 ring-orange-300'
      case 'Converted': return 'bg-blue-100 text-blue-800 ring-2 ring-blue-300'
      case 'Proposal Sent': return 'bg-indigo-100 text-indigo-800 ring-2 ring-indigo-300'
      case 'Not Interested': return 'bg-gray-100 text-gray-800 ring-2 ring-gray-300'
      case 'Invalid': return 'bg-purple-100 text-purple-800 ring-2 ring-purple-300'
      default: return 'bg-blue-100 text-blue-800 ring-2 ring-blue-300'
    }
  }
  
  getBaseClass(statusType, statusValue) {
    switch(statusType) {
      case 'customer_type':
        switch(statusValue) {
          case 'High Value': return 'bg-amber-50 text-amber-700'
          default: return 'bg-yellow-900/10 text-yellow-900'
        }

      case 'call_status':
        switch(statusValue) {
          case 'Called': return 'bg-green-50 text-green-700'
          case 'Incorrect Number': return 'bg-red-50 text-red-700'
          case 'Pending': return 'bg-yellow-50 text-yellow-700'
          case 'Followup': return 'bg-orange-50 text-orange-700'
          case 'Connected': return 'bg-blue-50 text-blue-700'
          default: return 'bg-gray-50 text-gray-700'
        }
        
      case 'email_status':
        switch(statusValue) {
          case 'Email Sent': return 'bg-green-50 text-green-700'
          case 'Incorrect Email': return 'bg-red-50 text-red-700'
          case 'Pending': return 'bg-yellow-50 text-yellow-700'
          case 'Followup': return 'bg-orange-50 text-orange-700'
          case 'Conversation Initiated': return 'bg-blue-50 text-blue-700'
          default: return 'bg-gray-50 text-gray-700'
        }
        
      case 'whatsapp_status':
        switch(statusValue) {
          case 'WhatsApp Message Sent': return 'bg-green-50 text-green-700'
          case 'Incorrect Number': return 'bg-red-50 text-red-700'
          case 'Pending': return 'bg-yellow-50 text-yellow-700'
          case 'Followup': return 'bg-orange-50 text-orange-700'
          case 'Conversation Initiated': return 'bg-blue-50 text-blue-700'
          default: return 'bg-gray-50 text-gray-700'
        }
        
      case 'linkedin_status':
        switch(statusValue) {
          case 'Message Sent': return 'bg-green-50 text-green-700'
          case 'Pending': return 'bg-yellow-50 text-yellow-700'
          case 'Followup': return 'bg-orange-50 text-orange-700'
          case 'Conversation Initiated': return 'bg-blue-50 text-blue-700'
          default: return 'bg-gray-50 text-gray-700'
        }
        
      default:
        return 'bg-gray-50 text-gray-700'
    }
  }
  
  getActiveClass(statusType, statusValue) {
    switch(statusType) {
      case 'customer_type':
        switch(statusValue) {
          case 'High Value': return 'bg-amber-100 text-amber-800 ring-2 ring-amber-300'
          default: return 'bg-yellow-900/20 text-yellow-900 ring-2 ring-yellow-900/30'
        }

      case 'call_status':
        switch(statusValue) {
          case 'Called': return 'bg-green-100 text-green-800 ring-2 ring-green-300'
          case 'Incorrect Number': return 'bg-red-100 text-red-800 ring-2 ring-red-300'
          case 'Pending': return 'bg-yellow-100 text-yellow-800 ring-2 ring-yellow-300'
          case 'Followup': return 'bg-orange-100 text-orange-800 ring-2 ring-orange-300'
          case 'Connected': return 'bg-blue-100 text-blue-800 ring-2 ring-blue-300'
          default: return 'bg-gray-100 text-gray-800 ring-2 ring-gray-300'
        }
        
      case 'email_status':
        switch(statusValue) {
          case 'Email Sent': return 'bg-green-100 text-green-800 ring-2 ring-green-300'
          case 'Incorrect Email': return 'bg-red-100 text-red-800 ring-2 ring-red-300'
          case 'Pending': return 'bg-yellow-100 text-yellow-800 ring-2 ring-yellow-300'
          case 'Followup': return 'bg-orange-100 text-orange-800 ring-2 ring-orange-300'
          case 'Conversation Initiated': return 'bg-blue-100 text-blue-800 ring-2 ring-blue-300'
          default: return 'bg-gray-100 text-gray-800 ring-2 ring-gray-300'
        }
        
      case 'whatsapp_status':
        switch(statusValue) {
          case 'WhatsApp Message Sent': return 'bg-green-100 text-green-800 ring-2 ring-green-300'
          case 'Incorrect Number': return 'bg-red-100 text-red-800 ring-2 ring-red-300'
          case 'Pending': return 'bg-yellow-100 text-yellow-800 ring-2 ring-yellow-300'
          case 'Followup': return 'bg-orange-100 text-orange-800 ring-2 ring-orange-300'
          case 'Conversation Initiated': return 'bg-blue-100 text-blue-800 ring-2 ring-blue-300'
          default: return 'bg-gray-100 text-gray-800 ring-2 ring-gray-300'
        }
        
      case 'linkedin_status':
        switch(statusValue) {
          case 'Message Sent': return 'bg-green-100 text-green-800 ring-2 ring-green-300'
          case 'Pending': return 'bg-yellow-100 text-yellow-800 ring-2 ring-yellow-300'
          case 'Followup': return 'bg-orange-100 text-orange-800 ring-2 ring-orange-300'
          case 'Conversation Initiated': return 'bg-blue-100 text-blue-800 ring-2 ring-blue-300'
          default: return 'bg-gray-100 text-gray-800 ring-2 ring-gray-300'
        }
        
      default:
        return 'bg-gray-100 text-gray-800 ring-2 ring-gray-300'
    }
  }
  
  showNotification(message, type) {
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 px-4 py-2 rounded-md shadow-md z-50 ${ 
      type === 'success' ? 'bg-green-50 text-green-800' : 'bg-red-50 text-red-800' 
    }`
    notification.textContent = message
    document.body.appendChild(notification)
    
    // Remove notification after 3 seconds
    setTimeout(() => {
      notification.remove()
    }, 3000)
  }
} 