import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dropdown", "statusBadge"]
  static values = { customerId: Number }

  connect() {
    // Close dropdown when clicking outside
    this.boundCloseDropdown = this.closeDropdown.bind(this)
  }

  disconnect() {
    document.removeEventListener('click', this.boundCloseDropdown)
  }

  openDropdown(event) {
    event.stopPropagation()
    
    // Toggle dropdown visibility
    if (this.dropdownTarget.classList.contains('hidden')) {
      this.dropdownTarget.classList.remove('hidden')
      // Add click listener to close dropdown when clicking outside
      setTimeout(() => {
        document.addEventListener('click', this.boundCloseDropdown)
      }, 10)
    } else {
      this.closeDropdown()
    }
  }

  closeDropdown() {
    this.dropdownTarget.classList.add('hidden')
    document.removeEventListener('click', this.boundCloseDropdown)
  }

  async updateStatus(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const newStatus = event.currentTarget.dataset.status
    const currentStatus = this.statusBadgeTarget.dataset.status
    
    // Don't update if same status
    if (newStatus === currentStatus) {
      this.closeDropdown()
      return
    }
    
    try {
      // Show loading state
      const originalText = this.statusBadgeTarget.textContent
      this.statusBadgeTarget.textContent = 'Updating...'
      this.statusBadgeTarget.className = 'inline-flex items-center px-3 py-1 rounded-full text-xs font-medium bg-gray-100 text-gray-600'
      
      // Make API request
      const response = await fetch(`/customers/${this.customerIdValue}/update_status`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Accept': 'application/json'
        },
        body: JSON.stringify({ status: newStatus })
      })
      
      const data = await response.json()
      
      if (data.success) {
        // Update badge with new status
        this.statusBadgeTarget.textContent = newStatus
        this.statusBadgeTarget.dataset.status = newStatus
        
        // Update badge color class
        const colorClass = this.getStatusColorClass(newStatus)
        this.statusBadgeTarget.className = `inline-flex items-center px-3 py-1 rounded-full text-xs font-medium ${colorClass}`
        
        // Show success message
        this.showNotification('Status updated successfully', 'success')
        
        // Close dropdown
        this.closeDropdown()
        
        // Reload page after a short delay to update activities
        setTimeout(() => {
          window.location.reload()
        }, 800)
      } else {
        throw new Error(data.errors ? data.errors.join(', ') : 'Failed to update status')
      }
    } catch (error) {
      console.error('Error updating status:', error)
      
      // Restore original status
      this.statusBadgeTarget.textContent = currentStatus
      const colorClass = this.getStatusColorClass(currentStatus)
      this.statusBadgeTarget.className = `inline-flex items-center px-3 py-1 rounded-full text-xs font-medium ${colorClass}`
      
      // Show error message
      this.showNotification(error.message || 'Failed to update status', 'error')
      
      // Close dropdown
      this.closeDropdown()
    }
  }

  getStatusColorClass(status) {
    const colorMap = {
      'Pending': 'bg-yellow-100 text-yellow-800',
      'Contact Established': 'bg-green-100 text-green-800',
      'Contact Not Established': 'bg-red-100 text-red-800',
      'Unresponsive': 'bg-orange-100 text-orange-800',
      'Converted': 'bg-emerald-100 text-emerald-800',
      'Proposal Sent': 'bg-emerald-100 text-emerald-800',
      'Not Interested': 'bg-gray-100 text-gray-800',
      'Exhausted': 'bg-purple-100 text-purple-800',
      'Invalid': 'bg-purple-100 text-purple-800',
      'Retarget': 'bg-amber-100 text-amber-800',
      'Exhausted_1': 'bg-pink-100 text-pink-800'
    }
    
    return colorMap[status] || 'bg-gray-100 text-gray-800'
  }

  showNotification(message, type = 'success') {
    // Create notification element
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 z-50 px-6 py-3 rounded-lg shadow-lg ${
      type === 'success' ? 'bg-green-500 text-white' : 'bg-red-500 text-white'
    }`
    notification.textContent = message
    
    // Add to page
    document.body.appendChild(notification)
    
    // Remove after 3 seconds
    setTimeout(() => {
      notification.remove()
    }, 3000)
  }
}
