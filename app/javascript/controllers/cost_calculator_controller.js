import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "modal", 
    "form", 
    "loadingState", 
    "results", 
    "featuresDisplay", 
    "costSummary", 
    "calculateButton", 
    "saveButton",
    "proposalButton"
  ]

  static values = {
    currentEstimate: Object
  }

  connect() {
    console.log("Cost calculator controller connected")
    // Set up modal close handlers
    this.boundCloseOnEscape = this.closeOnEscape.bind(this)
    document.addEventListener('keydown', this.boundCloseOnEscape)
  }

  disconnect() {
    document.removeEventListener('keydown', this.boundCloseOnEscape)
  }

  openModal() {
    console.log("Opening cost calculator modal")
    this.modalTarget.classList.remove('hidden')
    document.body.style.overflow = 'hidden'
    
    // Reset form state
    this.resetForm()
  }

  closeModal() {
    this.modalTarget.classList.add('hidden')
    document.body.style.overflow = 'auto'
    
    // Reset form state
    this.resetForm()
  }

  closeOnEscape(event) {
    if (event.key === 'Escape' && !this.modalTarget.classList.contains('hidden')) {
      this.closeModal()
    }
  }

  async calculateCost() {
    const formData = new FormData(this.formTarget)
    const appType = formData.get('app_type')
    const description = formData.get('description')
    const scale = formData.get('scale')
    const hourlyRate = formData.get('hourly_rate')

    // Basic validation
    if (!appType) {
      alert('Please select an application type')
      return
    }

    if (!scale) {
      alert('Please select a project scale')
      return
    }

    if (!description || description.trim().length < 10) {
      alert('Please provide a detailed project description (at least 10 characters)')
      return
    }

    if (!hourlyRate || parseFloat(hourlyRate) <= 0) {
      alert('Please provide a valid hourly rate')
      return
    }

    // Show loading state
    this.showLoadingState()

    try {
      const response = await fetch('/cost_estimates/analyze', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({
          app_type: appType,
          description: description,
          scale: scale,
          hourly_rate: hourlyRate
        })
      })

      const data = await response.json()

      if (data.success) {
        this.currentEstimateValue = {
          app_type: appType,
          description: description,
          scale: scale,
          hourly_rate: hourlyRate,
          ...data
        }
        this.displayResults(data)
      } else {
        this.showError(data.error || 'Failed to analyze project')
      }
    } catch (error) {
      console.error('Cost calculation error:', error)
      this.showError('Network error. Please try again.')
    } finally {
      this.hideLoadingState()
    }
  }

  async saveEstimate() {
    if (!this.currentEstimateValue) {
      alert('Please calculate cost first')
      return
    }

    try {
      const response = await fetch('/cost_estimates', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({
          cost_estimate: {
            app_type: this.currentEstimateValue.app_type,
            description: this.currentEstimateValue.description,
            scale: this.currentEstimateValue.scale,
            hourly_rate: this.currentEstimateValue.hourly_rate
          }
        })
      })

      const data = await response.json()

      if (data.success) {
        alert('Cost estimate saved successfully!')
        this.closeModal()
        
        // Optionally redirect to estimates index or refresh page
        if (window.location.pathname === '/cost_estimates') {
          window.location.reload()
        }
      } else {
        this.showError(data.errors?.join(', ') || 'Failed to save estimate')
      }
    } catch (error) {
      console.error('Save estimate error:', error)
      this.showError('Network error. Please try again.')
    }
  }

  async generateProposal() {
    if (!this.currentEstimateValue || !this.currentEstimateValue.estimate_id) {
      alert('Please save the estimate first before generating a proposal')
      return
    }

    try {
      // Create a temporary form and submit to generate PDF
      const form = document.createElement('form')
      form.method = 'GET'
      form.action = `/cost_estimates/${this.currentEstimateValue.estimate_id}/generate_proposal`
      form.target = '_blank'
      
      document.body.appendChild(form)
      form.submit()
      document.body.removeChild(form)
      
    } catch (error) {
      console.error('Proposal generation error:', error)
      this.showError('Failed to generate proposal. Please try again.')
    }
  }

  showLoadingState() {
    this.loadingStateTarget.classList.remove('hidden')
    this.resultsTarget.classList.add('hidden')
    this.calculateButtonTarget.disabled = true
    this.calculateButtonTarget.textContent = 'Analyzing...'
  }

  hideLoadingState() {
    this.loadingStateTarget.classList.add('hidden')
    this.calculateButtonTarget.disabled = false
    this.calculateButtonTarget.textContent = 'Calculate Cost'
  }

  displayResults(data) {
    // Show results section
    this.resultsTarget.classList.remove('hidden')
    
    // Display features
    this.displayFeatures(data.features)
    
    // Display cost summary
    this.displayCostSummary(data)
    
    // Show save and proposal buttons
    this.saveButtonTarget.classList.remove('hidden')
    this.proposalButtonTarget.classList.remove('hidden')
  }

  displayFeatures(features) {
    this.featuresDisplayTarget.innerHTML = ''
    
    if (!features || features.length === 0) {
      this.featuresDisplayTarget.innerHTML = '<p class="text-sm text-gray-500">No specific features identified</p>'
      return
    }

    // Group features by category
    const groupedFeatures = features.reduce((acc, feature) => {
      const category = feature.category || 'General'
      if (!acc[category]) {
        acc[category] = []
      }
      acc[category].push(feature)
      return acc
    }, {})

    // Create HTML for each category
    Object.entries(groupedFeatures).forEach(([category, categoryFeatures]) => {
      const categoryDiv = document.createElement('div')
      categoryDiv.className = 'mb-3'
      
      categoryDiv.innerHTML = `
        <h5 class="text-sm font-semibold text-gray-800 mb-1">${category}</h5>
        <div class="space-y-1">
          ${categoryFeatures.map(feature => `
            <div class="flex justify-between items-center text-sm">
              <div class="flex-1">
                <span class="text-gray-700">${feature.name}</span>
                ${feature.description ? `<span class="text-gray-500 text-xs block">${feature.description}</span>` : ''}
              </div>
              <div class="flex items-center space-x-2">
                <span class="px-2 py-1 rounded text-xs ${this.getComplexityColor(feature.complexity)}">${feature.complexity}</span>
                <span class="font-medium text-gray-900">${feature.hours}h</span>
              </div>
            </div>
          `).join('')}
        </div>
      `
      
      this.featuresDisplayTarget.appendChild(categoryDiv)
    })
  }

  displayCostSummary(data) {
    this.costSummaryTarget.innerHTML = `
      <div class="space-y-2">
        <div class="flex justify-between items-center">
          <span class="text-sm text-gray-600">Total Hours:</span>
          <span class="font-medium">${data.total_hours}</span>
        </div>
        <div class="flex justify-between items-center">
          <span class="text-sm text-gray-600">Hourly Rate:</span>
          <span class="font-medium">$${data.hourly_rate}/hour</span>
        </div>
        <div class="border-t pt-2">
          <div class="flex justify-between items-center">
            <span class="text-base font-semibold text-gray-900">Total Cost:</span>
            <span class="text-xl font-bold text-blue-600">${data.formatted_cost}</span>
          </div>
        </div>
      </div>
    `
  }

  getComplexityColor(complexity) {
    switch (complexity?.toLowerCase()) {
      case 'low':
        return 'bg-green-100 text-green-800'
      case 'high':
        return 'bg-red-100 text-red-800'
      case 'medium':
      default:
        return 'bg-yellow-100 text-yellow-800'
    }
  }

  showError(message) {
    alert(message) // Simple alert for now, could be enhanced with a proper error display
  }

  resetForm() {
    // Reset form fields
    if (this.hasFormTarget) {
      this.formTarget.reset()
    }
    
    // Hide results and loading states
    if (this.hasResultsTarget) {
      this.resultsTarget.classList.add('hidden')
    }
    
    if (this.hasLoadingStateTarget) {
      this.loadingStateTarget.classList.add('hidden')
    }
    
    if (this.hasSaveButtonTarget) {
      this.saveButtonTarget.classList.add('hidden')
    }
    
    if (this.hasProposalButtonTarget) {
      this.proposalButtonTarget.classList.add('hidden')
    }
    
    // Reset button state
    if (this.hasCalculateButtonTarget) {
      this.calculateButtonTarget.disabled = false
      this.calculateButtonTarget.textContent = 'Calculate Cost'
    }
    
    // Clear current estimate
    this.currentEstimateValue = null
  }
}