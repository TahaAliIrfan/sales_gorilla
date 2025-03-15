import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="phone-modal"
export default class extends Controller {
  static targets = ["modal", "phoneInput", "errorMessage"]
  
  connect() {
    // Show the modal if it's marked as needed
    if (this.element.dataset.showModal === "true") {
      this.openModal()
    }
  }
  
  openModal() {
    this.modalTarget.classList.remove("hidden")
  }
  
  closeModal() {
    this.modalTarget.classList.add("hidden")
  }
  
  save(event) {
    event.preventDefault()
    
    const phoneNumber = this.phoneInputTarget.value.trim()
    
    // Basic validation
    if (!phoneNumber) {
      this.showError("Phone number is required")
      return
    }
    
    if (!phoneNumber.startsWith('+')) {
      this.showError("Phone number must start with a + sign")
      return
    }
    
    if (!/^\+\d{6,15}$/.test(phoneNumber)) {
      this.showError("Please enter a valid phone number with country code (e.g. +923001234567)")
      return
    }
    
    // Find the form within the modal and submit it
    const form = this.element.querySelector('form')
    if (form) {
      form.submit()
    } else {
      this.showError("Form not found. Please try again or contact support.")
    }
  }
  
  showError(message) {
    this.errorMessageTarget.textContent = message
    this.errorMessageTarget.classList.remove("hidden")
  }
}
