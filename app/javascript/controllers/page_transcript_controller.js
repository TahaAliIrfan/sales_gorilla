import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    id: Number
  }
  
  connect() {
    this.loadTranscript()
  }
  
  loadTranscript() {
    fetch(`/recordings/${this.idValue}/transcript`)
      .then(response => {
        if (!response.ok) {
          throw new Error('Network response was not ok')
        }
        return response.json()
      })
      .then(data => {
        let transcriptHtml = ''
        
        // Check if data is an array (typical transcript format)
        if (Array.isArray(data)) {
          data.forEach(segment => {
            const speaker = segment.speaker === 'customer' ? 'Customer' : 'Agent'
            const speakerClass = segment.speaker === 'customer' ? 'bg-blue-100' : 'bg-green-100'
            
            transcriptHtml += `
              <div class="mb-4">
                <div class="text-xs font-medium text-gray-500 mb-1">${speaker}</div>
                <div class="p-3 rounded-lg ${speakerClass}">
                  <p class="text-sm text-gray-800">${segment.text}</p>
                </div>
              </div>
            `
          })
        } else {
          // If it's an object or other format, display as is
          transcriptHtml = `
            <div class="p-3 rounded-lg bg-gray-100">
              <p class="text-sm text-gray-800">${JSON.stringify(data, null, 2)}</p>
            </div>
          `
        }
        
        this.element.innerHTML = transcriptHtml
      })
      .catch(error => {
        this.element.innerHTML = `
          <div class="bg-red-50 border-l-4 border-red-400 p-4">
            <div class="flex">
              <div class="flex-shrink-0">
                <svg class="h-5 w-5 text-red-400" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor">
                  <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
                </svg>
              </div>
              <div class="ml-3">
                <p class="text-sm text-red-700">
                  Error loading transcript: ${error.message}
                </p>
              </div>
            </div>
          </div>
        `
      })
  }
} 