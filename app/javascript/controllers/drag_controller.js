import { Controller } from "@hotwired/stimulus"
// We'll use the global Sortable object instead of importing it directly
// import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["stage", "deal"]

  connect() {
    console.log("Drag controller connected")
    console.log(`Found ${this.stageTargets.length} stage targets`)
    
    // Wait for Sortable to be available
    if (window.Sortable) {
      this.initSortable()
    } else {
      console.error("Sortable.js not loaded")
      // Try again in 500ms
      setTimeout(() => this.initSortable(), 500)
    }
  }

  initSortable() {
    if (!window.Sortable) {
      console.error("Sortable.js still not loaded")
      return
    }
    
    this.stageTargets.forEach(stage => {
      const stageId = stage.dataset.stageId
      console.log(`Initializing Sortable for stage ${stageId}`)
      
      window.Sortable.create(stage, {
        group: 'deals',
        animation: 150,
        ghostClass: 'bg-gray-100',
        handle: '.drag-handle',
        onEnd: (event) => {
          this.moveDeal(event)
        }
      })
    })
  }

  moveDeal(event) {
    // Get the deal ID and the new stage ID
    const dealId = event.item.dataset.dealId
    const newStageId = event.to.dataset.stageId
    
    console.log(`Moving deal ${dealId} to stage ${newStageId}`)
    
    // Don't do anything if the deal is moved to the same stage
    if (event.from.dataset.stageId === newStageId) {
      console.log("Deal moved to the same stage, no action needed")
      return
    }
    
    // Send a request to update the deal's stage
    fetch(`/deals/${dealId}/update_stage`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ deal_stage_id: newStageId })
    })
    .then(response => {
      if (!response.ok) {
        console.error("Error response from server")
        // If the request fails, reload the page to reset the UI
        window.location.reload()
        return Promise.reject("Server error")
      }
      return response.json()
    })
    .then(data => {
      console.log("Response data:", data)
      if (data.success) {
        // Update the UI to reflect the change
        this.updateDealCounts()
      } else {
        console.error("Operation failed:", data.errors)
        // If there's an error, reload the page
        window.location.reload()
      }
    })
    .catch(error => {
      console.error('Error:', error)
      window.location.reload()
    })
  }

  updateDealCounts() {
    // Update the deal counts for each stage
    this.stageTargets.forEach(stage => {
      const stageId = stage.dataset.stageId
      const dealCount = stage.querySelectorAll('[data-drag-target="deal"]').length
      const countElement = document.querySelector(`[data-stage-id="${stageId}"] .deal-count`)
      if (countElement) {
        countElement.textContent = dealCount
      }
    })
  }
} 