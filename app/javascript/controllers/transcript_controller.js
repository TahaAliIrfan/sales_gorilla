import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["modal", "content", "audioPlayer"]
  
  connect() {
    this.transcriptData = null
  }
  
  show(event) {
    const recordingId = event.currentTarget.dataset.recordingId
    console.log('Opening transcript for recording:', recordingId)
    
    this.contentTarget.innerHTML = '<div class="flex justify-center items-center py-4"><div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500"></div></div>'
    
    // Show modal
    this.modalTarget.classList.remove('hidden')
    
    fetch(`/recordings/${recordingId}/transcript`)
      .then(response => {
        console.log('Transcript API response:', response.status)
        return response.json().then(data => ({
          status: response.status,
          body: data
        }))
      })
      .then(({ status, body }) => {
        console.log('Transcript data received:', body)
        
        if (status !== 200) {
          throw new Error(body.error || 'Failed to load transcript')
        }
        
        // Ensure body is an array
        if (!Array.isArray(body)) {
          console.log('Received data type:', typeof body)
          if (typeof body === 'string') {
            try {
              body = JSON.parse(body)
            } catch (e) {
              console.error('Failed to parse transcript string:', e)
              throw new Error('Invalid transcript format')
            }
          } else {
            throw new Error('Invalid transcript format')
          }
        }
        
        this.transcriptData = body
        this.contentTarget.innerHTML = ''
        
        body.forEach((item, index) => {
          const div = document.createElement('div')
          div.id = `transcript-${index}`
          div.className = 'p-3 rounded transition-colors duration-200'
          div.innerHTML = `
            <p class="text-sm text-gray-500 mb-1">Speaker ${item.speaker === 0 ? 'Customer' : 'Agent'} (${this.formatTime(item.start)})</p>
            <p class="text-gray-900">${item.transcript}</p>
          `
          this.contentTarget.appendChild(div)
        })
      })
      .catch(error => {
        console.error('Error fetching transcript:', error)
        this.contentTarget.innerHTML = `
          <div class="text-center text-red-600 py-4">
            <p>Error loading transcript: ${error.message}</p>
            <p class="text-sm mt-2">Please try again or contact support if the issue persists.</p>
          </div>
        `
      })
  }
  
  close() {
    this.modalTarget.classList.add('hidden')
    this.transcriptData = null
  }
  
  closeWithEscape(event) {
    if (event.key === 'Escape') {
      this.close()
    }
  }
  
  closeWithClick(event) {
    if (event.target === this.modalTarget) {
      this.close()
    }
  }
  
  updateHighlight() {
    if (!this.transcriptData || !this.hasAudioPlayerTarget) return
    
    const currentTime = this.audioPlayerTarget.currentTime
    const previousHighlight = document.querySelector('.bg-blue-50')
    if (previousHighlight) {
      previousHighlight.classList.remove('bg-blue-50')
    }
    
    const currentSegment = this.transcriptData.find(item => 
      currentTime >= item.start && currentTime <= item.end
    )
    
    if (currentSegment) {
      const index = this.transcriptData.indexOf(currentSegment)
      const element = document.getElementById(`transcript-${index}`)
      if (element) {
        element.classList.add('bg-blue-50')
        element.scrollIntoView({ behavior: 'smooth', block: 'nearest' })
      }
    }
  }
  
  formatTime(seconds) {
    const minutes = Math.floor(seconds / 60)
    const remainingSeconds = Math.floor(seconds % 60)
    return `${minutes}:${remainingSeconds.toString().padStart(2, '0')}`
  }
} 