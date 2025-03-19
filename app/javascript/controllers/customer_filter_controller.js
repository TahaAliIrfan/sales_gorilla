import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "search", 
    "user", 
    "leadSource",
    "sort", 
    "direction", 
    "customersList", 
    "noResults", 
    "resultsCount", 
    "activeFilters", 
    "searchBadge", 
    "searchText", 
    "userBadge", 
    "userText",
    "leadSourceBadge",
    "leadSourceText"
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
           urlParams.has('lead_source') || urlParams.has('sort') || 
           urlParams.has('direction')
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
    
    // Set lead source dropdown from URL parameter
    const leadSourceParam = urlParams.get('lead_source')
    if (leadSourceParam) {
      this.leadSourceTarget.value = leadSourceParam
    }
    
    // Set sort options from URL parameters
    const sortParam = urlParams.get('sort')
    if (sortParam && this.sortTarget.querySelector(`option[value="${sortParam}"]`)) {
      this.sortTarget.value = sortParam
    }
    
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
      
      if (storedFilters.userId) {
        this.userTarget.value = storedFilters.userId
      }
      
      if (storedFilters.leadSource) {
        this.leadSourceTarget.value = storedFilters.leadSource
      }
      
      if (storedFilters.sortBy && this.sortTarget.querySelector(`option[value="${storedFilters.sortBy}"]`)) {
        this.sortTarget.value = storedFilters.sortBy
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
      filters.leadSource || 
      (filters.sortBy && filters.sortBy !== 'created_at') || 
      (filters.sortDirection && filters.sortDirection !== 'desc')
    )
  }

  saveFiltersToStorage() {
    const filters = {
      search: this.searchTarget.value.trim(),
      userId: this.userTarget.value,
      leadSource: this.leadSourceTarget.value,
      sortBy: this.sortTarget.value,
      sortDirection: this.directionTarget.value
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
    const userId = this.userTarget.value
    const leadSource = this.leadSourceTarget.value
    const sortBy = this.sortTarget.value
    const sortDirection = this.directionTarget.value
    
    // Save filters to sessionStorage for persistence
    this.saveFiltersToStorage()
    
    // Build URL parameters
    const params = new URLSearchParams()
    
    // Add search param if present
    if (searchTerm) {
      params.append('search', searchTerm)
    }
    
    // Add user_id param if present
    if (userId) {
      params.append('user_id', userId)
    }
    
    // Add lead_source param if present
    if (leadSource) {
      params.append('lead_source', leadSource)
    }
    
    // Add sorting params
    if (sortBy) {
      params.append('sort', sortBy)
    }
    
    if (sortDirection) {
      params.append('direction', sortDirection)
    }
    
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
    const userId = this.userTarget.value
    const userText = userId ? this.userTarget.options[this.userTarget.selectedIndex].text : ''
    const leadSource = this.leadSourceTarget.value
    const leadSourceText = leadSource ? this.leadSourceTarget.options[this.leadSourceTarget.selectedIndex].text : ''
    
    // Update search badge
    this.searchBadgeTarget.classList.toggle('hidden', !searchTerm)
    if (searchTerm) {
      this.searchTextTarget.textContent = `Search: ${searchTerm}`
    }
    
    // Update user badge
    this.userBadgeTarget.classList.toggle('hidden', !userId)
    if (userId) {
      this.userTextTarget.textContent = `Assigned to: ${userText}`
    }
    
    // Update lead source badge
    this.leadSourceBadgeTarget.classList.toggle('hidden', !leadSource)
    if (leadSource) {
      this.leadSourceTextTarget.textContent = `Lead Source: ${leadSourceText}`
    }
    
    // Show/hide active filters section
    const hasActiveFilters = searchTerm || userId || leadSource
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
  
  clearLeadSource() {
    this.leadSourceTarget.value = ''
    this.filter()
  }
  
  clearAll() {
    this.searchTarget.value = ''
    this.userTarget.value = ''
    this.leadSourceTarget.value = ''
    this.sortTarget.value = 'created_at'
    this.directionTarget.value = 'desc'
    
    // Clear stored filters
    sessionStorage.removeItem('customerFilters')
    
    this.filter()
  }
} 