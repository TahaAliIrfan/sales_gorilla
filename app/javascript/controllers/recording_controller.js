import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["player", "audio"]
  
  connect() {
    // Initialize the recording controller
  }
  
  play(event) {
    const url = event.currentTarget.dataset.url
    const recordingId = event.currentTarget.dataset.recordingId
    
    this.playerTarget.classList.remove('hidden')
    this.audioTarget.src = url
    this.audioTarget.dataset.recordingId = recordingId
    
    this.audioTarget.play().catch(error => {
      console.error('Error playing audio:', error)
    })
  }
} 