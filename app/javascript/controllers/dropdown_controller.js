import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dropdown"
export default class extends Controller {
  static targets = ["menu"]
  
  connect() {
    this.closeOnClickOutside = this.closeOnClickOutside.bind(this)
    document.addEventListener("click", this.closeOnClickOutside)
    
    // Add event listener for the mark all as read button
    const markAllReadBtn = this.element.querySelector("#mark-all-read-btn")
    if (markAllReadBtn) {
      markAllReadBtn.addEventListener("click", this.markAllAsRead.bind(this))
    }
    
    // Add event listeners for individual notification items
    this.setupNotificationItems()
  }
  
  disconnect() {
    document.removeEventListener("click", this.closeOnClickOutside)
  }
  
  toggle(event) {
    event.stopPropagation()
    this.menuTarget.classList.toggle("hidden")
  }
  
  closeOnClickOutside(event) {
    if (!this.element.contains(event.target) && !this.menuTarget.classList.contains("hidden")) {
      this.menuTarget.classList.add("hidden")
    }
  }
  
  markAllAsRead(event) {
    event.preventDefault()
    
    // Send AJAX request to mark all as read
    fetch('/notifications/mark_all_as_read', {
      method: 'POST',
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
        'Content-Type': 'application/json',
        'Accept': 'application/json'
      },
      credentials: 'same-origin'
    })
    .then(response => response.json())
    .then(data => {
      if (data.success) {
        // Update the UI
        const notificationCount = document.getElementById("notification-count")
        if (notificationCount) {
          notificationCount.classList.add("hidden")
        }
        
        // Update the notification items in the dropdown
        const notificationItems = this.element.querySelectorAll('.bg-blue-50')
        notificationItems.forEach(item => {
          item.classList.remove('bg-blue-50')
          item.classList.add('bg-white')
          
          // Remove the blue dot
          const dot = item.querySelector('.h-2.w-2.bg-blue-500')
          if (dot) {
            dot.remove()
          }
          
          // Remove the "Mark as read" button
          const markAsReadBtn = item.querySelector('form')
          if (markAsReadBtn) {
            markAsReadBtn.remove()
          }
        })
      }
    })
    .catch(error => {
      console.error('Error marking notifications as read:', error)
    })
  }
  
  setupNotificationItems() {
    const notificationItems = this.element.querySelectorAll('[data-notification-id]')
    
    notificationItems.forEach(item => {
      const markAsReadBtn = item.querySelector('form button')
      if (markAsReadBtn) {
        markAsReadBtn.addEventListener('click', (event) => {
          event.stopPropagation()
          const form = event.target.closest('form')
          const notificationId = item.dataset.notificationId
          
          // Send AJAX request to mark as read
          fetch(form.action, {
            method: 'POST',
            headers: {
              'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
              'Content-Type': 'application/json',
              'Accept': 'application/json'
            },
            credentials: 'same-origin'
          })
          .then(response => response.json())
          .then(data => {
            if (data.success) {
              // Update UI
              item.classList.remove('bg-blue-50')
              item.classList.add('bg-white')
              
              // Remove the blue dot
              const dot = item.querySelector('.h-2.w-2.bg-blue-500')
              if (dot) {
                dot.remove()
              }
              
              // Remove the "Mark as read" button
              form.remove()
              
              // Decrement notification count
              const notificationCount = document.getElementById("notification-count")
              if (notificationCount) {
                const count = parseInt(notificationCount.textContent) - 1
                if (count <= 0) {
                  notificationCount.classList.add("hidden")
                } else {
                  notificationCount.textContent = count
                }
              }
            }
          })
          .catch(error => {
            console.error('Error marking notification as read:', error)
          })
        })
      }
    })
  }
} 