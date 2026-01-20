import { Controller } from "@hotwired/stimulus"

// Email Inbox Controller
// Handles email list filtering, searching, sync, and compose modal
export default class extends Controller {
  static targets = [
    "emailList", "emailItem", "filterBtn", "searchInput", "emptyState",
    "syncBtn", "syncIcon", "syncText", "composeModal",
    "totalCount", "allCount", "inboxCount", "sentCount", "unreadBadge"
  ]
  static values = { customerId: Number }

  connect() {
    this.currentFilter = 'all'
    this.searchQuery = ''
    this.checkUrlParams()
  }

  checkUrlParams() {
    const urlParams = new URLSearchParams(window.location.search)
    if (urlParams.get('compose') === 'true') {
      setTimeout(() => this.openCompose(), 200)
      // Clean up URL
      const url = new URL(window.location)
      url.searchParams.delete('compose')
      window.history.replaceState({}, '', url)
    }
  }

  // Filter methods
  filterAll() { this.setFilter('all') }
  filterInbox() { this.setFilter('received') }
  filterSent() { this.setFilter('sent') }
  filterUnread() { this.setFilter('unread') }

  setFilter(filter) {
    this.currentFilter = filter
    this.updateFilterButtons(filter)
    this.applyFilters()
  }

  updateFilterButtons(activeFilter) {
    this.filterBtnTargets.forEach(btn => {
      const isActive = btn.dataset.filter === activeFilter
      btn.classList.toggle('bg-white', isActive)
      btn.classList.toggle('text-gray-900', isActive)
      btn.classList.toggle('shadow-sm', isActive)
      btn.classList.toggle('text-gray-600', !isActive)
    })
  }

  search(event) {
    this.searchQuery = event.target.value.toLowerCase()
    this.applyFilters()
  }

  applyFilters() {
    const items = this.emailItemTargets.length > 0 
      ? this.emailItemTargets 
      : this.element.querySelectorAll('.email-item')
    
    let visibleCount = 0

    items.forEach(item => {
      const status = item.dataset.status
      const isUnread = item.dataset.unread === 'true'
      const subject = item.dataset.subject || ''
      const from = item.dataset.from || ''

      let matchesFilter = true

      // Apply status filter
      switch(this.currentFilter) {
        case 'received':
          matchesFilter = status === 'received'
          break
        case 'sent':
          matchesFilter = status === 'sent'
          break
        case 'unread':
          matchesFilter = isUnread
          break
        case 'all':
        default:
          matchesFilter = true
      }

      // Apply search filter
      if (matchesFilter && this.searchQuery) {
        const snippet = item.querySelector('.text-gray-500.truncate')?.textContent?.toLowerCase() || ''
        matchesFilter = subject.includes(this.searchQuery) || 
                        from.includes(this.searchQuery) || 
                        snippet.includes(this.searchQuery)
      }

      item.style.display = matchesFilter ? '' : 'none'
      if (matchesFilter) visibleCount++
    })

    // Show/hide empty state
    if (this.hasEmptyStateTarget) {
      const hasItems = items.length > 0
      this.emptyStateTarget.classList.toggle('hidden', visibleCount > 0 || !hasItems)
    }
  }

  async syncEmails() {
    if (this.hasSyncBtnTarget) {
      this.syncBtnTarget.disabled = true
    }
    if (this.hasSyncIconTarget) {
      this.syncIconTarget.classList.add('animate-spin')
    }
    if (this.hasSyncTextTarget) {
      this.syncTextTarget.textContent = 'Syncing...'
    }

    try {
      const response = await fetch(`/customers/${this.customerIdValue}/emails/fetch`, {
        method: 'GET',
        headers: {
          'X-CSRF-Token': this.csrfToken,
          'Accept': 'text/html'
        }
      })

      // Reload the page to show updated emails
      window.location.reload()
    } catch (error) {
      console.error('Sync error:', error)
      alert('Failed to sync emails. Please try again.')
      
      if (this.hasSyncBtnTarget) {
        this.syncBtnTarget.disabled = false
      }
      if (this.hasSyncIconTarget) {
        this.syncIconTarget.classList.remove('animate-spin')
      }
      if (this.hasSyncTextTarget) {
        this.syncTextTarget.textContent = 'Sync'
      }
    }
  }

  get composeModalElement() {
    return this.hasComposeModalTarget ? this.composeModalTarget : document.getElementById('compose-modal')
  }

  openCompose() {
    const modal = this.composeModalElement
    if (modal) {
      modal.classList.remove('hidden')
      modal.classList.add('flex')
      document.body.style.overflow = 'hidden'
      
      // Focus subject field
      const subjectField = modal.querySelector('input[name="subject"]')
      if (subjectField) {
        setTimeout(() => subjectField.focus(), 100)
      }
    }
  }

  closeCompose(event) {
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }
    
    const modal = this.composeModalElement
    if (modal) {
      modal.classList.add('hidden')
      modal.classList.remove('flex')
      document.body.style.overflow = ''

      // Reset form via composer controller
      const composerEl = modal.querySelector('[data-controller*="email-composer"]')
      if (composerEl) {
        const composerController = this.application.getControllerForElementAndIdentifier(composerEl, 'email-composer')
        if (composerController && composerController.reset) {
          composerController.reset()
        }
      }
    }
  }

  closeComposeOnBackground(event) {
    const modal = this.composeModalElement
    if (event.target === modal) {
      this.closeCompose()
    }
  }

  closeComposeOnEscape(event) {
    const modal = this.composeModalElement
    if (event.key === 'Escape' && modal && !modal.classList.contains('hidden')) {
      this.closeCompose()
    }
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
