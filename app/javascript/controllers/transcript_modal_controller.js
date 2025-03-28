import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    id: Number
  }
  
  open() {
    const modal = document.getElementById('transcript-modal')
    const content = document.getElementById('transcript-content')
    
    // Show the modal
    modal.classList.remove('hidden')
    
    // Show loading state
    content.innerHTML = `
      <div class="text-center py-8">
        <svg class="animate-spin h-10 w-10 text-blue-600 mx-auto" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        <p class="mt-2 text-sm text-gray-500">Loading transcript...</p>
      </div>
    `
    
    // Fetch the transcript
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
        
        content.innerHTML = transcriptHtml
      })
      .catch(error => {
        content.innerHTML = `
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