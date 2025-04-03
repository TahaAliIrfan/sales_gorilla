import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String
  }
  
  play() {
    const modal = document.getElementById('audio-player-modal')
    const audioPlayer = document.getElementById('audio-player')
    
    // Set the audio source
    audioPlayer.src = this.urlValue
    
    // Show the modal
    modal.classList.remove('hidden')
    
    // Play the audio
    audioPlayer.load()
    audioPlayer.play()
  }
} 