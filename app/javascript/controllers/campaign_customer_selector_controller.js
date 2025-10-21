import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["customerItem", "searchInput", "leadSourceFilter", "selectAllCheckbox", "selectedCount"]

  connect() {
    this.updateSelectedCount()
  }

  filter() {
    const searchTerm = this.searchInputTarget.value.toLowerCase()
    const leadSource = this.leadSourceFilterTarget.value.toLowerCase()

    this.customerItemTargets.forEach(item => {
      const customerName = item.dataset.customerName.toLowerCase()
      const customerEmail = item.dataset.customerEmail.toLowerCase()
      const customerPhone = item.dataset.customerPhone.toLowerCase()
      const customerLeadSource = item.dataset.customerLeadSource.toLowerCase()

      const matchesSearch = searchTerm === '' ||
                           customerName.includes(searchTerm) ||
                           customerEmail.includes(searchTerm) ||
                           customerPhone.includes(searchTerm)

      const matchesLeadSource = leadSource === '' || customerLeadSource === leadSource

      if (matchesSearch && matchesLeadSource) {
        item.classList.remove('hidden')
      } else {
        item.classList.add('hidden')
      }
    })

    this.updateSelectAllState()
  }

  toggleSelectAll(event) {
    const checked = event.target.checked
    const visibleCheckboxes = this.getVisibleCheckboxes()

    visibleCheckboxes.forEach(checkbox => {
      checkbox.checked = checked
    })

    this.updateSelectedCount()
  }

  updateSelectedCount() {
    const selectedCount = this.getSelectedCheckboxes().length
    if (this.hasSelectedCountTarget) {
      this.selectedCountTarget.textContent = selectedCount
    }
  }

  updateSelectAllState() {
    if (!this.hasSelectAllCheckboxTarget) return

    const visibleCheckboxes = this.getVisibleCheckboxes()
    const selectedCheckboxes = visibleCheckboxes.filter(cb => cb.checked)

    if (visibleCheckboxes.length === 0) {
      this.selectAllCheckboxTarget.checked = false
      this.selectAllCheckboxTarget.indeterminate = false
    } else if (selectedCheckboxes.length === visibleCheckboxes.length) {
      this.selectAllCheckboxTarget.checked = true
      this.selectAllCheckboxTarget.indeterminate = false
    } else if (selectedCheckboxes.length > 0) {
      this.selectAllCheckboxTarget.checked = false
      this.selectAllCheckboxTarget.indeterminate = true
    } else {
      this.selectAllCheckboxTarget.checked = false
      this.selectAllCheckboxTarget.indeterminate = false
    }
  }

  getVisibleCheckboxes() {
    return this.customerItemTargets
      .filter(item => !item.classList.contains('hidden'))
      .map(item => item.querySelector('input[type="checkbox"]'))
      .filter(checkbox => checkbox !== null)
  }

  getSelectedCheckboxes() {
    return this.customerItemTargets
      .map(item => item.querySelector('input[type="checkbox"]'))
      .filter(checkbox => checkbox !== null && checkbox.checked)
  }
}
