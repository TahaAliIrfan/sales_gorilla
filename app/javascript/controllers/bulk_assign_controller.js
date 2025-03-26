import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["checkbox", "bulkActions", "selectedCount", "bulkCustomerIds"]
  
  connect() {
    console.log("Bulk assign controller connected")
    this.setupEventListeners()
    // Initial state update
    this.updateBulkActions()
    
    // Force check for initial state
    setTimeout(() => this.updateBulkActions(), 300)
  }

  setupEventListeners() {
    // Use event delegation for checkboxes to handle dynamically loaded content
    document.addEventListener('change', (event) => {
      if (event.target.matches('.customer-checkbox, #select-all-checkbox')) {
        console.log(`Checkbox changed: ${event.target.className}, checked: ${event.target.checked}, data-id: ${event.target.getAttribute('data-id')}`)
        this.updateBulkActions()
      }
    })
    
    // Add event listeners for the select all checkbox
    const selectAllCheckbox = document.getElementById("select-all-checkbox")
    if (selectAllCheckbox) {
      selectAllCheckbox.addEventListener("change", this.toggleSelectAll.bind(this))
    }
    
    // Add event listeners for the buttons in the bulk actions bar
    const selectAllButton = document.getElementById("select-all")
    if (selectAllButton) {
      selectAllButton.addEventListener("click", this.selectAll.bind(this))
    }
    
    const clearSelectionButton = document.getElementById("clear-selection")
    if (clearSelectionButton) {
      clearSelectionButton.addEventListener("click", this.clearSelection.bind(this))
    }
    
    const bulkAssignButton = document.getElementById("bulk-assign-btn")
    if (bulkAssignButton) {
      bulkAssignButton.addEventListener("click", this.openBulkAssignModal.bind(this))
    } else {
      console.error("Bulk assign button not found")
    }
    
    // Add event listeners for the bulk assign modal
    const closeModalButton = document.getElementById("close-modal")
    if (closeModalButton) {
      closeModalButton.addEventListener("click", this.closeBulkAssignModal.bind(this))
    }
    
    const cancelBulkAssignButton = document.getElementById("cancel-bulk-assign")
    if (cancelBulkAssignButton) {
      cancelBulkAssignButton.addEventListener("click", this.closeBulkAssignModal.bind(this))
    }

    // Ensure form submission captures all selected items
    const bulkAssignForm = document.getElementById("bulk-assign-form")
    if (bulkAssignForm) {
      console.log("Found bulk assign form:", bulkAssignForm)
      bulkAssignForm.addEventListener("submit", this.handleFormSubmit.bind(this))
    } else {
      console.error("Bulk assign form not found")
    }
  }
  
  handleFormSubmit(event) {
    // Prevent default form submission to ensure we can set field values
    event.preventDefault()
    console.log("Form submission intercepted")
    
    // Get all selected IDs just before submission
    this.updateHiddenFields()
    
    // Double check if we actually have values in the hidden fields
    let proceed = false
    const customerIdsField = document.getElementById("bulk-customer-ids")
    
    if (customerIdsField && customerIdsField.value) {
      console.log(`Submitting with customer IDs: ${customerIdsField.value}`)
      proceed = true
    }
    
    if (!proceed) {
      console.error("No customers selected for bulk assignment")
      alert("Please select at least one customer to assign.")
      return
    }
    
    // Now submit the form
    console.log("Manually submitting form")
    event.target.submit()
  }
  
  updateHiddenFields() {
    // Update customer IDs directly on the form input element
    const selectedCustomerCheckboxes = document.querySelectorAll(".customer-checkbox:checked")
    const bulkCustomerIdsInput = document.getElementById("bulk-customer-ids")
    
    if (selectedCustomerCheckboxes.length > 0 && bulkCustomerIdsInput) {
      const selectedCustomerIds = Array.from(selectedCustomerCheckboxes)
          .map(checkbox => checkbox.getAttribute("data-id"))
          .filter(id => id && id !== "")
      
      if (selectedCustomerIds.length > 0) {
        console.log(`Setting customer IDs: ${selectedCustomerIds.join(',')}`)
        bulkCustomerIdsInput.value = selectedCustomerIds.join(",")
      }
    } else if (bulkCustomerIdsInput) {
      bulkCustomerIdsInput.value = ""
    }
  }
  
  toggleSelectAll(event) {
    const isChecked = event.target.checked
    
    // Select all customer checkboxes
    const customerCheckboxes = document.querySelectorAll(".customer-checkbox")
    customerCheckboxes.forEach(checkbox => {
      checkbox.checked = isChecked
    })
    
    this.updateBulkActions()
  }
  
  selectAll(event) {
    event.preventDefault()
    
    // Select all customer checkboxes
    const customerCheckboxes = document.querySelectorAll(".customer-checkbox")
    customerCheckboxes.forEach(checkbox => {
      checkbox.checked = true
    })
    
    // Update the select all checkbox
    const selectAllCheckbox = document.getElementById("select-all-checkbox")
    if (selectAllCheckbox) {
      selectAllCheckbox.checked = true
    }
    
    this.updateBulkActions()
  }
  
  clearSelection(event) {
    event.preventDefault()
    
    // Unselect all customer checkboxes
    const customerCheckboxes = document.querySelectorAll(".customer-checkbox")
    customerCheckboxes.forEach(checkbox => {
      checkbox.checked = false
    })
    
    // Update the select all checkbox
    const selectAllCheckbox = document.getElementById("select-all-checkbox")
    if (selectAllCheckbox) {
      selectAllCheckbox.checked = false
    }
    
    this.updateBulkActions()
  }
  
  updateBulkActions() {
    // Count selected customers
    const selectedCustomerCheckboxes = document.querySelectorAll(".customer-checkbox:checked")
    const selectedCustomerCount = selectedCustomerCheckboxes.length
    
    // Update the selected count in the bulk actions bar
    const selectedCountElement = document.getElementById("selected-count")
    if (selectedCountElement) {
      selectedCountElement.textContent = `${selectedCustomerCount} selected`
    }
    
    // Show or hide the bulk actions bar
    const bulkActionsBar = document.getElementById("bulk-actions-bar")
    if (bulkActionsBar) {
      if (selectedCustomerCount > 0) {
        bulkActionsBar.classList.remove("hidden")
      } else {
        bulkActionsBar.classList.add("hidden")
      }
    }
    
    // Update hidden fields
    this.updateHiddenFields()
  }
  
  openBulkAssignModal(event) {
    event.preventDefault()
    
    // Double check the selection count
    const selectedCustomerCheckboxes = document.querySelectorAll(".customer-checkbox:checked")
    const totalSelected = selectedCustomerCheckboxes.length
    
    if (totalSelected === 0) {
      console.error("No customers selected for bulk assignment")
      alert("Please select at least one customer to assign.")
      return
    }
    
    // Update hidden fields with current selection just before opening modal
    this.updateHiddenFields()
    
    // Show the bulk assign modal
    const bulkAssignModal = document.getElementById("bulk-assign-modal")
    if (bulkAssignModal) {
      bulkAssignModal.classList.remove("hidden")
    }
  }
  
  closeBulkAssignModal(event) {
    event.preventDefault()
    
    // Hide the bulk assign modal
    const bulkAssignModal = document.getElementById("bulk-assign-modal")
    if (bulkAssignModal) {
      bulkAssignModal.classList.add("hidden")
    }
  }
} 