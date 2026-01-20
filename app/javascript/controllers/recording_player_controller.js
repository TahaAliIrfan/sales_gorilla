import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content", "collapseIcon", "expandIcon", "transcriptContainer"]
  static values = { 
    recordingId: Number,
    expanded: Boolean
  }

  connect() {
    this.expandedValue = false
  }

  toggle() {
    this.expandedValue = !this.expandedValue
    
    if (this.expandedValue) {
      this.expand()
    } else {
      this.collapse()
    }
  }

  expand() {
    this.contentTarget.classList.remove('hidden')
    this.collapseIconTarget.classList.remove('hidden')
    this.expandIconTarget.classList.add('hidden')
    
    // Load transcript if not already loaded
    if (this.hasTranscriptContainerTarget && !this.transcriptContainerTarget.dataset.loaded) {
      this.loadTranscript()
    }
  }

  collapse() {
    this.contentTarget.classList.add('hidden')
    this.collapseIconTarget.classList.add('hidden')
    this.expandIconTarget.classList.remove('hidden')
  }

  loadTranscript() {
    const transcriptContainer = this.transcriptContainerTarget
    transcriptContainer.dataset.loaded = 'true'
    
    transcriptContainer.innerHTML = `
      <div class="flex items-center justify-center py-4">
        <svg class="animate-spin h-6 w-6 text-blue-600 mr-2" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        <span class="text-sm text-gray-600">Loading transcript...</span>
      </div>
    `

    fetch(`/recordings/${this.recordingIdValue}/transcript`)
      .then(response => {
        if (!response.ok) {
          throw new Error('Transcript not available')
        }
        return response.json()
      })
      .then(data => {
        transcriptContainer.innerHTML = this.formatTranscript(data)
      })
      .catch(error => {
        transcriptContainer.innerHTML = `
          <div class="text-center py-4">
            <p class="text-sm text-gray-500">${error.message}</p>
          </div>
        `
      })
  }

  formatTranscript(data) {
    try {
      if (typeof data === 'string' && (data.startsWith('[') || data.startsWith('{'))) {
        data = JSON.parse(data)
      }
      
      if (Array.isArray(data)) {
        return this.formatArrayTranscript(data)
      } else if (typeof data === 'string') {
        return `<div class="p-3 rounded-lg bg-gray-50"><p class="text-sm text-gray-800 whitespace-pre-wrap">${data}</p></div>`
      } else if (typeof data === 'object' && data !== null) {
        if (data.transcript || data.text) {
          const text = data.transcript || data.text
          return `<div class="p-3 rounded-lg bg-gray-50"><p class="text-sm text-gray-800 whitespace-pre-wrap">${text}</p></div>`
        } else if (Array.isArray(data.segments)) {
          return this.formatArrayTranscript(data.segments)
        }
      }
      
      return `<div class="text-center py-4"><p class="text-sm text-gray-500">Unable to display transcript</p></div>`
    } catch (error) {
      return `<div class="text-center py-4"><p class="text-sm text-red-500">Error formatting transcript</p></div>`
    }
  }

  formatArrayTranscript(segments) {
    if (segments.length === 0) {
      return `<div class="text-center py-4"><p class="text-sm text-gray-500">No transcript content</p></div>`
    }

    let html = '<div class="space-y-3">'
    
    segments.forEach((segment, index) => {
      const text = segment.text || segment.transcript || segment.content || "No text"
      const speaker = this.determineSpeaker(segment, index)
      const bgColor = speaker === 'Customer' ? 'bg-blue-50' : 'bg-green-50'
      
      html += `
        <div class="flex items-start space-x-2">
          <div class="flex-shrink-0 w-20">
            <span class="text-xs font-medium text-gray-600">${speaker}</span>
          </div>
          <div class="flex-1 p-2 rounded-lg ${bgColor}">
            <p class="text-sm text-gray-800">${text}</p>
          </div>
        </div>
      `
    })
    
    html += '</div>'
    return html
  }

  determineSpeaker(segment, index) {
    const speakerField = segment.speaker || segment.speakerLabel || segment.speakerId
    
    if (speakerField) {
      const speakerLower = String(speakerField).toLowerCase()
      
      if (speakerLower.includes('customer') || speakerLower.includes('client') || 
          speakerLower === 'a' || speakerLower === 'speaker_a' ||
          speakerLower === 'spk_0' || speakerLower === '0') {
        return 'Customer'
      } else if (speakerLower.includes('agent') || speakerLower.includes('rep') || 
               speakerLower === 'b' || speakerLower === 'speaker_b' ||
               speakerLower === 'spk_1' || speakerLower === '1') {
        return 'Agent'
      }
    }
    
    return index % 2 === 0 ? 'Customer' : 'Agent'
  }
}
