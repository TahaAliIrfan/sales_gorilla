import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="lead-source"
export default class extends Controller {
  static targets = ["select", "ccrFields", "ccrCost"]

  connect() {
    console.log("Lead Source controller connected")
    // Initialize the visibility of CCR fields based on the initial value
    this.toggleCcrFields()
  }

  toggleCcrFields() {
    console.log("Toggle CCR fields called")
    console.log("Select value:", this.selectTarget.value)
    
    // Check if the selected value is CCR
    const isCcr = this.selectTarget.value === 'CCR'
    
    if (isCcr) {
      console.log("Showing CCR fields")
      this.ccrFieldsTarget.classList.remove('hidden')
      this.ccrCostTarget.classList.remove('hidden')
    } else {
      console.log("Hiding CCR fields")
      this.ccrFieldsTarget.classList.add('hidden')
      this.ccrCostTarget.classList.add('hidden')
    }
  }
} 