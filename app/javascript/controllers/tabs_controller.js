import { Controller } from "@hotwired/stimulus"

// Tabs Controller
// Handles tab navigation with URL hash support
export default class extends Controller {
  static targets = ["tab", "content"]

  connect() {
    this.handleUrlHash()
    this.handleUrlParams()
  }

  switch(event) {
    const tabId = event.currentTarget.dataset.tabId
    if (tabId) {
      this.activateTab(tabId)
      // Update URL hash without scrolling
      history.replaceState(null, null, '#' + tabId)
    }
  }

  activateTab(tabId) {
    // Update tab buttons
    this.tabTargets.forEach(tab => {
      const isActive = tab.dataset.tabId === tabId
      tab.classList.toggle('border-blue-500', isActive)
      tab.classList.toggle('text-blue-600', isActive)
      tab.classList.toggle('active', isActive)
      tab.classList.toggle('border-transparent', !isActive)
      tab.classList.toggle('text-gray-500', !isActive)
    })

    // Update content panels
    this.contentTargets.forEach(content => {
      const shouldShow = content.dataset.tabId === tabId
      content.classList.toggle('hidden', !shouldShow)
    })
  }

  handleUrlHash() {
    const hash = window.location.hash.replace('#', '')
    if (hash) {
      const matchingTab = this.tabTargets.find(tab => tab.dataset.tabId === hash)
      if (matchingTab) {
        this.activateTab(hash)
      }
    }
  }

  handleUrlParams() {
    const urlParams = new URLSearchParams(window.location.search)
    if (urlParams.get('compose') === 'true') {
      // Switch to emails tab
      this.activateTab('emails')
      // Clean up URL
      history.replaceState(null, null, window.location.pathname + '#emails')
    }
  }
}
