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
    this.filter()
    
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
    const searchTerm = this.searchTarget.value.toLowerCase().trim()
    const userId = this.userTarget.value
    const sortBy = this.sortTarget.value
    const sortDirection = this.directionTarget.value
    
    // Update active filters display
    this.updateActiveFilters()
    
    // Get all customer rows
    const rows = this.customersListTarget.querySelectorAll('.customer-row')
    let visibleCount = 0
    
    // Filter and sort rows
    Array.from(rows).forEach(row => {
      // Filter by search term
      const name = row.dataset.name || ''
      const email = row.dataset.email || ''
      const company = row.dataset.company || ''
      const phone = row.dataset.phone || ''
      
      const matchesSearch = searchTerm === '' || 
        name.includes(searchTerm) || 
        email.includes(searchTerm) || 
        company.includes(searchTerm) || 
        phone.includes(searchTerm)
      
      // Filter by user
      const matchesUser = userId === '' || row.dataset.userId === userId
      
      // Show/hide row based on filters
      const shouldShow = matchesSearch && matchesUser
      row.classList.toggle('hidden', !shouldShow)
      
      if (shouldShow) {
        visibleCount++
      }
    })
    
    // Sort visible rows
    this.sortRows(sortBy, sortDirection)
    
    // Update results count
    this.updateResultsCount(visibleCount)
    
    // Show/hide no results message
    this.noResultsTarget.classList.toggle('hidden', visibleCount > 0)
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
    }, 150) // 150ms delay for smooth typing experience
  }
  
  sortRows(sortBy, direction) {
    const rows = Array.from(this.customersListTarget.querySelectorAll('.customer-row:not(.hidden)'))
    
    rows.sort((a, b) => {
      // Special handling for date fields (created_at, updated_at)
      if (sortBy === 'created_at' || sortBy === 'updated_at') {
        const aValue = parseInt(a.dataset[sortBy] || '0')
        const bValue = parseInt(b.dataset[sortBy] || '0')
        
        if (direction === 'asc') {
          return aValue - bValue
        } else {
          return bValue - aValue
        }
      } else {
        // Text-based sorting for other fields
        const aValue = (a.dataset[sortBy] || '').toLowerCase()
        const bValue = (b.dataset[sortBy] || '').toLowerCase()
        
        if (direction === 'asc') {
          return aValue.localeCompare(bValue)
        } else {
          return bValue.localeCompare(aValue)
        }
      }
    })
    
    // Reorder rows in the DOM
    rows.forEach(row => {
      this.customersListTarget.appendChild(row)
    })
  }
  
  updateResultsCount(count) {
    this.resultsCountTarget.textContent = `Showing ${count} customer${count !== 1 ? 's' : ''}`
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