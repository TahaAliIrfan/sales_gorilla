import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "search", 
    "user", 
    "leadSource",
    "customerType",
    "status",
    "direction", 
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
    "customerTypeBadge",
    "customerTypeText"
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
    
    // Set up debounce for search input
    this.searchDebounceTimeout = null
  }
  
  hasUrlParams() {
    const urlParams = new URLSearchParams(window.location.search)
    return urlParams.has('search') || urlParams.has('user_id') || 
           urlParams.has('status') || urlParams.has('lead_source') || 
           urlParams.has('customer_type') || urlParams.has('direction')
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
    if (userIdParam) {
      this.userTarget.value = userIdParam
    }
    
    // Set status dropdown from URL parameter
    const statusParam = urlParams.get('status')
    if (statusParam) {
      this.statusTarget.value = statusParam
    }
    
    // Set lead source dropdown from URL parameter
    const leadSourceParam = urlParams.get('lead_source')
    if (leadSourceParam) {
      this.leadSourceTarget.value = leadSourceParam
    }
    
    // Set customer type dropdown from URL parameter
    const customerTypeParam = urlParams.get('customer_type')
    if (customerTypeParam) {
      this.customerTypeTarget.value = customerTypeParam
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
      
      if (storedFilters.leadSource) {
        this.leadSourceTarget.value = storedFilters.leadSource
      }
      
      if (storedFilters.customerType) {
        this.customerTypeTarget.value = storedFilters.customerType
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
      filters.leadSource || 
      filters.customerType ||
      (filters.sortDirection && filters.sortDirection !== 'desc')
    )
  }

  saveFiltersToStorage() {
    const filters = {
      search: this.searchTarget.value.trim(),
      status: this.statusTarget.value,
      leadSource: this.leadSourceTarget.value,
      customerType: this.customerTypeTarget.value,
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
    const leadSource = this.leadSourceTarget.value
    const customerType = this.customerTypeTarget.value
    const sortDirection = this.directionTarget.value
    
    // Only use userId if the user target exists (for admin users)
    const userId = this.hasUserTarget ? this.userTarget.value : null
    
    // Debug logging
    console.log("Filter values:", {
      searchTerm,
      userId,
      status,
      leadSource,
      customerType,
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
    
    // Add lead_source param if present
    if (leadSource) {
      params.append('lead_source', leadSource)
    }
    
    // Add customer_type param if present
    if (customerType) {
      params.append('customer_type', customerType)
    }
    
    // Add direction param
    if (sortDirection) {
      params.append('direction', sortDirection)
    }
    
    // Debug logging
    console.log("Final URL params:", params.toString())
    
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
    const leadSource = this.leadSourceTarget.value
    const leadSourceText = leadSource ? this.leadSourceTarget.options[this.leadSourceTarget.selectedIndex].text : ''
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
    this.leadSourceBadgeTarget.classList.toggle('hidden', !leadSource)
    if (leadSource) {
      this.leadSourceTextTarget.textContent = `Lead Source: ${leadSourceText}`
    }
    
    // Update customer type badge
    this.customerTypeBadgeTarget.classList.toggle('hidden', !customerType)
    if (customerType) {
      this.customerTypeTextTarget.textContent = `Lead Type: ${customerTypeText}`
    }
    
    // Show/hide active filters section
    const hasActiveFilters = searchTerm || userId || status || leadSource || customerType
    this.activeFiltersTarget.classList.toggle('hidden', !hasActiveFilters)
  }
  
  clearSearch() {
    this.searchTarget.value = ''
    this.filter()
  }
  
  clearUser() {
    this.userTarget.value = ''
    this.filter()
  }
  
  clearStatus() {
    this.statusTarget.value = ''
    this.filter()
  }
  
  clearLeadSource() {
    this.leadSourceTarget.value = ''
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
    this.leadSourceTarget.value = ''
    this.customerTypeTarget.value = ''
    this.directionTarget.value = 'desc'
    
    // Clear stored filters
    sessionStorage.removeItem('customerFilters')
    
    this.filter()
  }
} 