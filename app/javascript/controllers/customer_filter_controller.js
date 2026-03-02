import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "search",
    "user",
    "leadSource",
    "leadSourceCheckbox",
    "leadSourceContainer",
    "customerType",
    "status",
    "direction",
    "startDate",
    "endDate",
    "customersList",
    "noResults",
    "resultsCount",
    "activeFilters",
    "searchBadge",
    "searchText",
    "userBadge",
    "userText",
    "statusBadge",
    "statusText",
    "leadSourceBadge",
    "leadSourceText",
    "dateRangeBadge",
    "dateRangeText",
    "customerTypeBadge",
    "customerTypeText",
    "exportLink"
  ]

  connect() {   
    // First check URL parameters, then fallback to sessionStorage if no URL params
    if (this.hasUrlParams()) {
      // Initialize filter inputs from URL parameters if present
      this.initializeFromUrlParams()
      // Store current filters in sessionStorage for persistence
      this.saveFiltersToStorage()
    } else {
      // Initialize from sessionStorage if available
      this.initializeFromStorage()
    }
    
    // Initialize filter state
    this.updateActiveFilters()
    
    // Sync export link with current URL params on load
    this.updateExportLinkFromUrl()
    
    // Set up debounce for search input
    this.searchDebounceTimeout = null
  }
  
  hasUrlParams() {
    const urlParams = new URLSearchParams(window.location.search)
    return urlParams.has('search') || urlParams.has('user_id') || 
           urlParams.has('status') || urlParams.has('lead_source') || 
           urlParams.has('customer_type') || urlParams.has('direction') ||
           urlParams.has('start_date') || urlParams.has('end_date')
  }
  
  initializeFromUrlParams() {
    // Get URL parameters
    const urlParams = new URLSearchParams(window.location.search)
    
    // Set search input from URL parameter
    const searchParam = urlParams.get('search')
    if (searchParam) {
      this.searchTarget.value = searchParam
    }
    
    // Set user dropdown from URL parameter
    const userIdParam = urlParams.get('user_id')
    if (userIdParam && this.hasUserTarget) {
      this.userTarget.value = userIdParam
    }
    
    // Set status dropdown from URL parameter
    const statusParam = urlParams.get('status')
    if (statusParam) {
      this.statusTarget.value = statusParam
    }
    
    // Set lead source checkboxes from URL parameter
    const leadSourceParams = urlParams.getAll('lead_source[]')
    if (leadSourceParams.length > 0 && this.hasLeadSourceCheckboxTarget) {
      this.leadSourceCheckboxTargets.forEach(checkbox => {
        checkbox.checked = leadSourceParams.includes(checkbox.value)
      })
      // Trigger multiselect dropdown update
      this.updateMultiselectButtonText()
    }
    
    // Set customer type dropdown from URL parameter
    const customerTypeParam = urlParams.get('customer_type')
    if (customerTypeParam) {
      this.customerTypeTarget.value = customerTypeParam
    }
    
    // Set date range parameters
    const startDateParam = urlParams.get('start_date')
    if (startDateParam && this.hasStartDateTarget) {
      this.startDateTarget.value = startDateParam
    }
    const endDateParam = urlParams.get('end_date')
    if (endDateParam && this.hasEndDateTarget) {
      this.endDateTarget.value = endDateParam
    }

    // Set direction parameter
    const directionParam = urlParams.get('direction')
    if (directionParam && this.directionTarget.querySelector(`option[value="${directionParam}"]`)) {
      this.directionTarget.value = directionParam
    }
  }

  initializeFromStorage() {
    // Get filters from sessionStorage
    const storedFilters = this.getFiltersFromStorage()
    
    if (storedFilters) {
      // Apply stored filters to form elements
      if (storedFilters.search) {
        this.searchTarget.value = storedFilters.search
      }
      
      // Only set user if target exists (admin only)
      if (storedFilters.userId && this.hasUserTarget) {
        this.userTarget.value = storedFilters.userId
      }
      
      if (storedFilters.status) {
        this.statusTarget.value = storedFilters.status
      }

      if (storedFilters.leadSources && Array.isArray(storedFilters.leadSources) && this.hasLeadSourceCheckboxTarget) {
        this.leadSourceCheckboxTargets.forEach(checkbox => {
          checkbox.checked = storedFilters.leadSources.includes(checkbox.value)
        })
        this.updateMultiselectButtonText()
      }
      
      if (storedFilters.customerType) {
        this.customerTypeTarget.value = storedFilters.customerType
      }
      
      if (storedFilters.startDate && this.hasStartDateTarget) {
        this.startDateTarget.value = storedFilters.startDate
      }
      if (storedFilters.endDate && this.hasEndDateTarget) {
        this.endDateTarget.value = storedFilters.endDate
      }

      if (storedFilters.sortDirection && this.directionTarget.querySelector(`option[value="${storedFilters.sortDirection}"]`)) {
        this.directionTarget.value = storedFilters.sortDirection
      }
      
      // If we have stored filters and they're not empty, apply them immediately
      if (this.hasStoredFilters(storedFilters)) {
        this.filter()
      }
    }
  }
  
  hasStoredFilters(filters) {
    return filters && (
      filters.search ||
      filters.userId ||
      filters.status ||
      (filters.leadSources && filters.leadSources.length > 0) ||
      filters.customerType ||
      filters.startDate ||
      filters.endDate ||
      (filters.sortDirection && filters.sortDirection !== 'desc')
    )
  }

  saveFiltersToStorage() {
    const filters = {
      search: this.searchTarget.value.trim(),
      status: this.statusTarget.value,
      leadSources: this.getSelectedLeadSources(),
      customerType: this.customerTypeTarget.value,
      startDate: this.hasStartDateTarget ? this.startDateTarget.value : '',
      endDate: this.hasEndDateTarget ? this.endDateTarget.value : '',
      sortDirection: this.directionTarget.value
    }

    // Only add userId if user target exists (admin only)
    if (this.hasUserTarget) {
      filters.userId = this.userTarget.value
    }

    // Store in sessionStorage
    sessionStorage.setItem('customerFilters', JSON.stringify(filters))
  }
  
  getFiltersFromStorage() {
    const storedFilters = sessionStorage.getItem('customerFilters')
    return storedFilters ? JSON.parse(storedFilters) : null
  }

  filter() {
    const searchTerm = this.searchTarget.value.trim()
    const status = this.statusTarget.value
    const leadSources = this.getSelectedLeadSources()
    const customerType = this.customerTypeTarget.value
    const startDate = this.hasStartDateTarget ? this.startDateTarget.value : ''
    const endDate = this.hasEndDateTarget ? this.endDateTarget.value : ''
    const sortDirection = this.directionTarget.value

    // Only use userId if the user target exists (for admin users)
    const userId = this.hasUserTarget ? this.userTarget.value : null

    // Debug logging
    console.log("Filter values:", {
      searchTerm,
      userId,
      status,
      leadSources,
      customerType,
      startDate,
      endDate,
      sortDirection,
      hasUserTarget: this.hasUserTarget
    })

    // Save filters to sessionStorage for persistence
    this.saveFiltersToStorage()

    // Build URL parameters
    const params = new URLSearchParams()

    // Add search param if present
    if (searchTerm) {
      params.append('search', searchTerm)
    }

    // Add user_id param if present and user has access to user filter
    if (userId && this.hasUserTarget) {
      params.append('user_id', userId)
    }

    // Add status param if present
    if (status) {
      console.log("Adding status to params:", status)
      params.append('status', status)
    }

    // Add lead_source params if present (multiple values)
    if (leadSources.length > 0) {
      leadSources.forEach(source => {
        params.append('lead_source[]', source)
      })
    }

    // Add customer_type param if present
    if (customerType) {
      params.append('customer_type', customerType)
    }

    // Add date range params if present
    if (startDate) {
      params.append('start_date', startDate)
    }
    if (endDate) {
      params.append('end_date', endDate)
    }

    // Add direction param
    if (sortDirection) {
      params.append('direction', sortDirection)
    }

    // Debug logging
    console.log("Final URL params:", params.toString())

    // Update export CSV link with current filters
    this.updateExportLink(params)

    // Navigate to the filtered URL
    window.location.href = `${window.location.pathname}?${params.toString()}`
  }
  
  // Debounced filter for search input
  debouncedFilter() {
    // Clear any existing timeout
    if (this.searchDebounceTimeout) {
      clearTimeout(this.searchDebounceTimeout)
    }
    
    // Set a new timeout to filter after a short delay
    this.searchDebounceTimeout = setTimeout(() => {
      this.filter()
    }, 500) // 500ms delay for search input
  }
  
  updateActiveFilters() {
    const searchTerm = this.searchTarget.value.trim()

    // Only get user value if target exists (admin only)
    const userId = this.hasUserTarget ? this.userTarget.value : null
    const userText = userId && this.hasUserTarget ? this.userTarget.options[this.userTarget.selectedIndex].text : ''

    const status = this.statusTarget.value
    const statusText = status ? this.statusTarget.options[this.statusTarget.selectedIndex].text : ''
    const leadSources = this.getSelectedLeadSources()
    const leadSourceText = leadSources.length > 0 ? (leadSources.length === 1 ? leadSources[0] : `${leadSources.length} Sources`) : ''
    const customerType = this.customerTypeTarget.value
    const customerTypeText = customerType ? this.customerTypeTarget.options[this.customerTypeTarget.selectedIndex].text : ''

    // Update search badge
    this.searchBadgeTarget.classList.toggle('hidden', !searchTerm)
    if (searchTerm) {
      this.searchTextTarget.textContent = `Search: ${searchTerm}`
    }

    // Update user badge only if target exists (admin only)
    if (this.hasUserTarget) {
      this.userBadgeTarget.classList.toggle('hidden', !userId)
      if (userId) {
        this.userTextTarget.textContent = `Assigned to: ${userText}`
      }
    }

    // Update status badge
    this.statusBadgeTarget.classList.toggle('hidden', !status)
    if (status) {
      this.statusTextTarget.textContent = `Status: ${statusText}`
    }

    // Update lead source badge
    this.leadSourceBadgeTarget.classList.toggle('hidden', leadSources.length === 0)
    if (leadSources.length > 0) {
      this.leadSourceTextTarget.textContent = `Lead Source: ${leadSourceText}`
    }

    // Update date range badge
    const startDate = this.hasStartDateTarget ? this.startDateTarget.value : ''
    const endDate = this.hasEndDateTarget ? this.endDateTarget.value : ''
    const hasDateRange = startDate || endDate
    this.dateRangeBadgeTarget.classList.toggle('hidden', !hasDateRange)
    if (hasDateRange) {
      let dateText = 'Dates: '
      if (startDate && endDate) {
        dateText += `${startDate} to ${endDate}`
      } else if (startDate) {
        dateText += `from ${startDate}`
      } else {
        dateText += `until ${endDate}`
      }
      this.dateRangeTextTarget.textContent = dateText
    }

    // Update customer type badge
    this.customerTypeBadgeTarget.classList.toggle('hidden', !customerType)
    if (customerType) {
      this.customerTypeTextTarget.textContent = `Lead Type: ${customerTypeText}`
    }

    // Show/hide active filters section
    const hasActiveFilters = searchTerm || userId || status || leadSources.length > 0 || hasDateRange || customerType
    this.activeFiltersTarget.classList.toggle('hidden', !hasActiveFilters)
  }
  
  clearSearch() {
    this.searchTarget.value = ''
    this.filter()
  }
  
  clearUser() {
    if (this.hasUserTarget) {
      this.userTarget.value = ''
      this.filter()
    }
  }
  
  clearStatus() {
    this.statusTarget.value = ''
    this.filter()
  }
  
  clearLeadSource() {
    if (this.hasLeadSourceCheckboxTarget) {
      this.leadSourceCheckboxTargets.forEach(checkbox => {
        checkbox.checked = false
      })
      this.updateMultiselectButtonText()
    }
    this.filter()
  }

  clearDateRange() {
    if (this.hasStartDateTarget) this.startDateTarget.value = ''
    if (this.hasEndDateTarget) this.endDateTarget.value = ''
    this.filter()
  }

  clearCustomerType() {
    this.customerTypeTarget.value = ''
    this.filter()
  }

  clearAll() {
    this.searchTarget.value = ''
    // Only clear user if target exists (admin only)
    if (this.hasUserTarget) {
      this.userTarget.value = ''
    }
    this.statusTarget.value = ''
    if (this.hasLeadSourceCheckboxTarget) {
      this.leadSourceCheckboxTargets.forEach(checkbox => {
        checkbox.checked = false
      })
      this.updateMultiselectButtonText()
    }
    this.customerTypeTarget.value = ''
    if (this.hasStartDateTarget) this.startDateTarget.value = ''
    if (this.hasEndDateTarget) this.endDateTarget.value = ''
    this.directionTarget.value = 'desc'

    // Clear stored filters
    sessionStorage.removeItem('customerFilters')

    this.filter()
  }

  getSelectedLeadSources() {
    if (!this.hasLeadSourceCheckboxTarget) return []
    return this.leadSourceCheckboxTargets
      .filter(checkbox => checkbox.checked)
      .map(checkbox => checkbox.value)
  }

  updateMultiselectButtonText() {
    if (!this.hasLeadSourceContainerTarget) return

    const multiselectController = this.application.getControllerForElementAndIdentifier(
      this.leadSourceContainerTarget,
      'multiselect-dropdown'
    )

    if (multiselectController && multiselectController.updateButtonText) {
      multiselectController.updateButtonText()
    }
  }

  updateExportLink(params) {
    if (!this.hasExportLinkTarget) return
    const baseUrl = this.exportLinkTarget.href.split('?')[0]
    const queryString = params.toString()
    this.exportLinkTarget.href = queryString ? `${baseUrl}?${queryString}` : baseUrl
  }

  updateExportLinkFromUrl() {
    if (!this.hasExportLinkTarget) return
    const currentParams = window.location.search
    const baseUrl = this.exportLinkTarget.href.split('?')[0]
    this.exportLinkTarget.href = currentParams ? `${baseUrl}${currentParams}` : baseUrl
  }
} 