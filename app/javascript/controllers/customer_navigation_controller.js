import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // Store the current controller name
    this.currentController = this.element.dataset.currentController
    
    // Add event listeners to all sidebar navigation links
    this.addNavigationListeners()
  }
  
  addNavigationListeners() {
    // Find all navigation links except customer links
    const nonCustomerLinks = document.querySelectorAll('nav a:not([href*="/customers"])')
    
    // Add click event listener to each link
    nonCustomerLinks.forEach(link => {
      link.addEventListener('click', this.handleNavigation.bind(this))
    })
  }
  
  handleNavigation(event) {
    // Only clear filters when navigating away from customers section
    if (this.currentController === 'customers') {
      // Clear stored customer filters
      sessionStorage.removeItem('customerFilters')
    }
  }
  
  disconnect() {
    // Clean up event listeners if needed when controller disconnects
    const nonCustomerLinks = document.querySelectorAll('nav a:not([href*="/customers"])')
    nonCustomerLinks.forEach(link => {
      link.removeEventListener('click', this.handleNavigation.bind(this))
    })
  }
} 