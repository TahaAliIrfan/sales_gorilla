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
      if (event.target.matches('.customer-checkbox')) {
        // Each customer is rendered twice (desktop table + mobile card) with the
        // same data-id. Keep both copies in sync so unchecking one view also
        // unchecks the other, otherwise the "unchecked" id leaks back in.
        const id = event.target.getAttribute('data-id')
        if (id) {
          document.querySelectorAll(`.customer-checkbox[data-id="${id}"]`).forEach(cb => {
            cb.checked = event.target.checked
          })
        }
        this.updateBulkActions()
      } else if (event.target.matches('#select-all-checkbox')) {
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
    
    const bulkStatusChangeButton = document.getElementById("bulk-status-change-btn")
    if (bulkStatusChangeButton) {
      bulkStatusChangeButton.addEventListener("click", this.openBulkStatusChangeModal.bind(this))
    } else {
      console.error("Bulk status change button not found")
    }

    const bulkDeleteButton = document.getElementById("bulk-delete-btn")
    if (bulkDeleteButton) {
      bulkDeleteButton.addEventListener("click", this.openBulkDeleteModal.bind(this))
    }

    const cancelBulkDeleteButton = document.getElementById("cancel-bulk-delete")
    if (cancelBulkDeleteButton) {
      cancelBulkDeleteButton.addEventListener("click", this.closeBulkDeleteModal.bind(this))
    }

    const bulkDeleteForm = document.getElementById("bulk-delete-form")
    if (bulkDeleteForm) {
      bulkDeleteForm.addEventListener("submit", this.handleDeleteFormSubmit.bind(this))
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
    
    // Add event listeners for the bulk status change modal
    const closeStatusModalButton = document.getElementById("close-status-modal")
    if (closeStatusModalButton) {
      closeStatusModalButton.addEventListener("click", this.closeBulkStatusChangeModal.bind(this))
    }
    
    const cancelBulkStatusChangeButton = document.getElementById("cancel-bulk-status-change")
    if (cancelBulkStatusChangeButton) {
      cancelBulkStatusChangeButton.addEventListener("click", this.closeBulkStatusChangeModal.bind(this))
    }

    // Ensure form submission captures all selected items
    const bulkAssignForm = document.getElementById("bulk-assign-form")
    if (bulkAssignForm) {
      console.log("Found bulk assign form:", bulkAssignForm)
      bulkAssignForm.addEventListener("submit", this.handleFormSubmit.bind(this))
    } else {
      console.error("Bulk assign form not found")
    }
    
    // Ensure form submission captures all selected items for status change
    const bulkStatusChangeForm = document.getElementById("bulk-status-change-form")
    if (bulkStatusChangeForm) {
      console.log("Found bulk status change form:", bulkStatusChangeForm)
      bulkStatusChangeForm.addEventListener("submit", this.handleStatusChangeFormSubmit.bind(this))
    } else {
      console.error("Bulk status change form not found")
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
  
  // Unique data-ids of all checked customer checkboxes. Deduped because each
  // customer has two checkboxes (desktop table + mobile card) sharing a data-id.
  selectedCustomerIds() {
    const ids = new Set()
    document.querySelectorAll(".customer-checkbox:checked").forEach(checkbox => {
      const id = checkbox.getAttribute("data-id")
      if (id && id !== "") {
        ids.add(id)
      }
    })
    return Array.from(ids)
  }

  updateHiddenFields() {
    // Update customer IDs directly on the form input elements
    const selectedCustomerIds = this.selectedCustomerIds()
    const bulkCustomerIdsInput = document.getElementById("bulk-customer-ids")
    const bulkStatusCustomerIdsInput = document.getElementById("bulk-status-customer-ids")
    const bulkDeleteCustomerIdsInput = document.getElementById("bulk-delete-customer-ids")

    if (selectedCustomerIds.length > 0) {
      const customerIdsString = selectedCustomerIds.join(",")
      console.log(`Setting customer IDs: ${customerIdsString}`)

      if (bulkCustomerIdsInput) {
        bulkCustomerIdsInput.value = customerIdsString
      }
      if (bulkStatusCustomerIdsInput) {
        bulkStatusCustomerIdsInput.value = customerIdsString
      }
      if (bulkDeleteCustomerIdsInput) {
        bulkDeleteCustomerIdsInput.value = customerIdsString
      }
    } else {
      if (bulkCustomerIdsInput) {
        bulkCustomerIdsInput.value = ""
      }
      if (bulkStatusCustomerIdsInput) {
        bulkStatusCustomerIdsInput.value = ""
      }
      if (bulkDeleteCustomerIdsInput) {
        bulkDeleteCustomerIdsInput.value = ""
      }
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
    // Count selected customers (deduped across desktop + mobile checkboxes)
    const selectedCustomerCount = this.selectedCustomerIds().length
    
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
    const totalSelected = this.selectedCustomerIds().length

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
  
  handleStatusChangeFormSubmit(event) {
    // Prevent default form submission to ensure we can set field values
    event.preventDefault()
    console.log("Status change form submission intercepted")
    
    // Get all selected IDs just before submission
    this.updateHiddenFields()
    
    // Double check if we actually have values in the hidden fields
    let proceed = false
    const statusCustomerIdsField = document.getElementById("bulk-status-customer-ids")
    
    if (statusCustomerIdsField && statusCustomerIdsField.value) {
      console.log(`Submitting status change with customer IDs: ${statusCustomerIdsField.value}`)
      proceed = true
    }
    
    if (!proceed) {
      console.error("No customers selected for bulk status change")
      alert("Please select at least one customer to change status.")
      return
    }
    
    // Now submit the form
    console.log("Manually submitting status change form")
    event.target.submit()
  }
  
  openBulkStatusChangeModal(event) {
    event.preventDefault()
    
    // Double check the selection count
    const totalSelected = this.selectedCustomerIds().length

    if (totalSelected === 0) {
      console.error("No customers selected for bulk status change")
      alert("Please select at least one customer to change status.")
      return
    }
    
    // Update hidden fields with current selection just before opening modal
    this.updateHiddenFields()
    
    // Show the bulk status change modal
    const bulkStatusChangeModal = document.getElementById("bulk-status-change-modal")
    if (bulkStatusChangeModal) {
      bulkStatusChangeModal.classList.remove("hidden")
    }
  }
  
  closeBulkStatusChangeModal(event) {
    event.preventDefault()

    // Hide the bulk status change modal
    const bulkStatusChangeModal = document.getElementById("bulk-status-change-modal")
    if (bulkStatusChangeModal) {
      bulkStatusChangeModal.classList.add("hidden")
    }
  }

  openBulkDeleteModal(event) {
    event.preventDefault()

    const totalSelected = this.selectedCustomerIds().length

    if (totalSelected === 0) {
      alert("Please select at least one customer to delete.")
      return
    }

    // Update hidden fields with current selection just before opening modal
    this.updateHiddenFields()

    // Reflect the selected count in the confirmation message
    const countElement = document.getElementById("bulk-delete-count")
    if (countElement) {
      countElement.textContent = totalSelected
    }

    const bulkDeleteModal = document.getElementById("bulk-delete-modal")
    if (bulkDeleteModal) {
      bulkDeleteModal.classList.remove("hidden")
    }
  }

  closeBulkDeleteModal(event) {
    event.preventDefault()

    const bulkDeleteModal = document.getElementById("bulk-delete-modal")
    if (bulkDeleteModal) {
      bulkDeleteModal.classList.add("hidden")
    }
  }

  handleDeleteFormSubmit(event) {
    event.preventDefault()

    // Get all selected IDs just before submission
    this.updateHiddenFields()

    const deleteCustomerIdsField = document.getElementById("bulk-delete-customer-ids")
    if (!deleteCustomerIdsField || !deleteCustomerIdsField.value) {
      alert("Please select at least one customer to delete.")
      return
    }

    event.target.submit()
  }
} 