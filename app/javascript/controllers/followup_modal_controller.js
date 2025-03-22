import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "form", "date", "time", "notes", "error", "calendar"]

  connect() {
    console.log("Followup modal controller connected")
    
    // Ensure the modal can be opened from any button in the page with data-action="click->followup-modal#open"
    document.querySelectorAll('[data-action*="click->followup-modal#open"]').forEach(button => {
      button.addEventListener('click', () => this.open())
    })
  }

  open() {
    console.log("Opening modal")
    this.modalTarget.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
    
    // Set default values for date and time
    this.dateTarget.value = this._getTomorrowDate()
    this.timeTarget.value = this._getCurrentTime()
    this.notesTarget.value = ""
    
    if (this.hasErrorTarget) {
      this.errorTarget.textContent = ""
      this.errorTarget.classList.add("hidden")
    }

    // Reset the submit button state
    if (document.getElementById('follow-up-submit-btn')) {
      const submitBtn = document.getElementById('follow-up-submit-btn')
      submitBtn.disabled = false
      submitBtn.classList.remove('opacity-75', 'cursor-not-allowed')
      submitBtn.innerText = 'Schedule Follow-up'
      
      if (document.getElementById('follow-up-loading')) {
        document.getElementById('follow-up-loading').classList.add('hidden')
      }
    }
  }

  close() {
    console.log("Closing modal")
    this.modalTarget.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
  }
  
  clickOutside(event) {
    if (event.target === this.modalTarget) {
      this.close()
    }
  }
  
  async submit(event) {
    event.preventDefault()
    
    // Set the submit button to loading state
    const submitBtn = document.getElementById('follow-up-submit-btn')
    const loadingEl = document.getElementById('follow-up-loading')
    
    if (submitBtn && loadingEl) {
      submitBtn.disabled = true
      submitBtn.classList.add('opacity-75', 'cursor-not-allowed')
      submitBtn.innerText = 'Scheduling...'
      loadingEl.classList.remove('hidden')
    }
    
    try {
      const response = await fetch(this.formTarget.action, {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content,
          "Accept": "application/json"
        },
        body: new FormData(this.formTarget)
      })
      
      const result = await response.json()
      
      if (response.ok) {
        this.close()
        
        // Refresh the page to show updated followup information
        window.location.reload()
      } else {
        if (this.hasErrorTarget) {
          this.errorTarget.textContent = result.error || "An error occurred while scheduling the follow-up."
          this.errorTarget.classList.remove("hidden")
        }
        
        // Reset the submit button state
        if (submitBtn && loadingEl) {
          submitBtn.disabled = false
          submitBtn.classList.remove('opacity-75', 'cursor-not-allowed')
          submitBtn.innerText = 'Schedule Follow-up'
          loadingEl.classList.add('hidden')
        }
      }
    } catch (error) {
      console.error("Error scheduling followup:", error)
      if (this.hasErrorTarget) {
        this.errorTarget.textContent = "An error occurred while scheduling the follow-up."
        this.errorTarget.classList.remove("hidden")
      }
      
      // Reset the submit button state
      if (submitBtn && loadingEl) {
        submitBtn.disabled = false
        submitBtn.classList.remove('opacity-75', 'cursor-not-allowed')
        submitBtn.innerText = 'Schedule Follow-up'
        loadingEl.classList.add('hidden')
      }
    }
  }
  
  _getTomorrowDate() {
    const tomorrow = new Date()
    tomorrow.setDate(tomorrow.getDate() + 1)
    return tomorrow.toISOString().split('T')[0]
  }
  
  _getCurrentTime() {
    const now = new Date()
    return `${String(now.getHours()).padStart(2, '0')}:${String(now.getMinutes()).padStart(2, '0')}`
  }
} 