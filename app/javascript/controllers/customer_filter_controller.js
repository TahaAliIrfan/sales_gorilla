import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "search", 
    "user", 
    "sort", 
    "direction", 
    "customersList", 
    "noResults", 
    "resultsCount", 
    "activeFilters", 
    "searchBadge", 
    "searchText", 
    "userBadge", 
    "userText"
  ]

  connect() {
    // Initialize filter inputs from URL parameters if present
    this.initializeFromUrlParams()
    
    // Initialize filter state
    this.updateActiveFilters()
    
    // Set up debounce for search input
    this.searchDebounceTimeout = null
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

  filter() {
    const searchTerm = this.searchTarget.value.trim()
    const userId = this.userTarget.value
    const sortBy = this.sortTarget.value
    const sortDirection = this.directionTarget.value
    
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
    
    // Show/hide active filters section
    const hasActiveFilters = searchTerm || userId
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
  
  clearAll() {
    this.searchTarget.value = ''
    this.userTarget.value = ''
    this.sortTarget.value = 'created_at'
    this.directionTarget.value = 'desc'
    this.filter()
  }
} 