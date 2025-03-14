import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "callButton", 
    "hangupButton", 
    "phoneNumber", 
    "callerId",
    "dealSelect",
    "callStatus", 
    "statusMessage", 
    "callControls",
    "dtmf",
    "refreshRecordings",
    "recordingsLoading",
    "noRecordings",
    "recordingsList",
    "recordingsTableBody",
    "recordingPlayer",
    "audioPlayer"
  ]

  connect() {
    this.device = null
    this.currentConnection = null
    this.setupDevice()
    this.fetchRecordings()
    this.updateCallButtonState()
  }

  // Handle deal selection
  onDealSelect(event) {
    const selectedOption = event.target.selectedOptions[0]
    const phone = selectedOption.dataset.phone || ''
    
    this.phoneNumberTarget.value = phone
    this.phoneNumberTarget.readOnly = true
    
    if (!phone) {
      this.showStatus('Unable to call lead as it has no phone number. Please add a number to the customer profile.', 'warning')
      this.callButtonTarget.disabled = true
      this.callButtonTarget.classList.add('opacity-50', 'cursor-not-allowed')
    } else {
      this.callStatusTarget.classList.add('hidden')
      this.callButtonTarget.disabled = false
      this.callButtonTarget.classList.remove('opacity-50', 'cursor-not-allowed')
    }
  }

  // Update call button state based on phone number
  updateCallButtonState() {
    const phoneNumber = this.phoneNumberTarget.value.trim()
    const dealSelected = this.dealSelectTarget.value !== ''
    
    if (phoneNumber && dealSelected) {
      this.callButtonTarget.disabled = false
      this.callButtonTarget.classList.remove('opacity-50', 'cursor-not-allowed')
    } else {
      this.callButtonTarget.disabled = true
      this.callButtonTarget.classList.add('opacity-50', 'cursor-not-allowed')
      
      if (dealSelected && !phoneNumber) {
        this.showStatus('Unable to call lead as it has no phone number. Please add a number to the customer profile.', 'warning')
      }
    }
  }

  // Initialize the Twilio Device
  async setupDevice() {
    this.showStatus('Requesting access token...')
    
    try {
      const response = await fetch('/calling/token')
      if (!response.ok) {
        throw new Error(`HTTP error! Status: ${response.status}`)
      }
      
      const data = await response.json()
      if (!data.token) {
        throw new Error('No token received from server')
      }
      
      this.showStatus('Initializing device...')
      console.log('Token received, initializing device...')
      
      this.device = new Twilio.Device(data.token, {
        logLevel: 3,
        enableRTCE: true,
        debug: true
      })
      
      this.setupDeviceListeners()
      
      this.showStatus('Ready to make calls')
      setTimeout(() => {
        this.callStatusTarget.classList.add('hidden')
      }, 3000)
    } catch (error) {
      console.error('Error setting up Twilio device:', error)
      this.showError(`Error initializing device: ${error.message}`)
    }
  }

  // Set up event listeners for the Twilio Device
  setupDeviceListeners() {
    this.device.on('ready', () => {
      console.log('Twilio Device is ready')
    })
    
    this.device.on('error', (error) => {
      console.error('Twilio Device Error:', error)
      let errorMessage = 'Error: '
      
      switch(error.code) {
        case 31000:
          errorMessage += 'Missing or invalid WebRTC requirements'
          break
        case 31002:
          errorMessage += 'Error with capability token. Check your Twilio credentials and TwiML app configuration.'
          break
        case 31003:
          errorMessage += 'Error registering with Twilio. Check your network connection.'
          break
        case 31005:
          errorMessage += 'Microphone access denied. Please allow microphone access.'
          break
        case 31008:
          errorMessage += 'Connection to Twilio failed. Check your network connection.'
          break
        case 31009:
          errorMessage += 'Call failed - the number may be invalid or unreachable.'
          break
        default:
          errorMessage += error.message || 'Unknown error'
      }
      
      this.showError(errorMessage)
    })
    
    this.device.on('connect', (conn) => {
      this.currentConnection = conn
      this.showStatus('Call in progress...', 'success')
      this.callControlsTarget.classList.remove('hidden')
    })
    
    this.device.on('disconnect', () => {
      this.currentConnection = null
      this.showStatus('Call ended', 'info')
      this.callControlsTarget.classList.add('hidden')
      
      setTimeout(() => {
        this.callStatusTarget.classList.add('hidden')
      }, 3000)
      
      setTimeout(() => this.fetchRecordings(), 5000)
    })
  }

  // Make an outgoing call
  makeCall(event) {
    event.preventDefault()
    const phoneNumber = this.phoneNumberTarget.value.trim()
    const callerId = this.callerIdTarget.value
    const dealId = this.dealSelectTarget.value
    
    if (!phoneNumber || !dealId) {
      this.showStatus('Please select a deal and ensure phone number is entered', 'warning')
      return
    }
    
    this.showStatus(`Calling ${phoneNumber} from ${callerId}...`, 'info')
    
    const params = {
      To: phoneNumber,
      caller_id: callerId,
      deal_id: dealId
    }
    
    console.log('Making call with params:', params)
    
    if (this.device) {
      try {
        this.currentConnection = this.device.connect(params)
        
        this.currentConnection.on('accept', () => {
          console.log('Call accepted')
        })
        
        this.currentConnection.on('error', (error) => {
          console.error('Call connection error:', error)
        })
      } catch (error) {
        console.error('Error connecting call:', error)
        this.showError('Error connecting call: ' + error.message)
      }
    } else {
      this.showError('Device not initialized. Please refresh the page.')
    }
  }

  // Hang up the current call
  hangUp(event) {
    event.preventDefault()
    if (this.currentConnection) {
      this.currentConnection.disconnect()
    }
  }

  // Send DTMF tones
  sendDigit(event) {
    const digit = event.currentTarget.dataset.digit
    if (this.currentConnection) {
      this.currentConnection.sendDigits(digit)
    }
  }

  // Fetch call recordings from the server
  async fetchRecordings() {
    this.recordingsLoadingTarget.classList.remove('hidden')
    this.noRecordingsTarget.classList.add('hidden')
    this.recordingsListTarget.classList.add('hidden')
    this.recordingPlayerTarget.classList.add('hidden')
    
    try {
      const response = await fetch('/calling/recordings')
      if (!response.ok) {
        throw new Error(`HTTP error! Status: ${response.status}`)
      }
      
      const recordings = await response.json()
      this.recordingsLoadingTarget.classList.add('hidden')
      this.recordingsTableBodyTarget.innerHTML = ''
      
      if (recordings.length === 0) {
        this.noRecordingsTarget.classList.remove('hidden')
      } else {
        this.recordingsListTarget.classList.remove('hidden')
        this.renderRecordings(recordings)
      }
    } catch (error) {
      console.error('Error fetching recordings:', error)
      this.recordingsLoadingTarget.classList.add('hidden')
      this.noRecordingsTarget.classList.remove('hidden')
      this.noRecordingsTarget.querySelector('p').textContent = `Error loading recordings: ${error.message}`
    }
  }

  // Render recordings in the table
  renderRecordings(recordings) {
    recordings.forEach(recording => {
      const date = new Date(recording.date)
      const formattedDate = date.toLocaleString()
      const minutes = Math.floor(recording.duration / 60)
      const seconds = recording.duration % 60
      const formattedDuration = `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`
      
      const row = document.createElement('tr')
      row.className = 'border-b border-gray-200 hover:bg-gray-100'
      row.innerHTML = `
        <td class="py-3 px-4">${formattedDate}</td>
        <td class="py-3 px-4">${formattedDuration}</td>
        <td class="py-3 px-4">
          <button class="play-recording bg-blue-500 hover:bg-blue-600 text-white px-3 py-1 rounded text-xs mr-2" 
                  data-action="click->calling#playRecording"
                  data-url="${recording.url}">
            <i class="fas fa-play"></i> Play
          </button>
          <a href="${recording.url}" download class="bg-gray-500 hover:bg-gray-600 text-white px-3 py-1 rounded text-xs">
            <i class="fas fa-download"></i> Download
          </a>
        </td>
      `
      
      this.recordingsTableBodyTarget.appendChild(row)
    })
  }

  // Play a recording
  playRecording(event) {
    const url = event.currentTarget.dataset.url
    this.recordingPlayerTarget.classList.remove('hidden')
    this.audioPlayerTarget.src = url
    this.audioPlayerTarget.play().catch(error => {
      console.error('Error playing audio:', error)
    })
  }

  // Helper method to show status messages
  showStatus(message, type = 'info') {
    this.statusMessageTarget.textContent = message
    this.callStatusTarget.classList.remove('hidden')
    
    // Remove all status classes
    this.callStatusTarget.classList.remove(
      'bg-blue-100', 'text-blue-800',
      'bg-green-100', 'text-green-800',
      'bg-red-100', 'text-red-800',
      'bg-yellow-100', 'text-yellow-800'
    )
    
    // Add appropriate status class
    switch(type) {
      case 'success':
        this.callStatusTarget.classList.add('bg-green-100', 'text-green-800')
        break
      case 'error':
        this.callStatusTarget.classList.add('bg-red-100', 'text-red-800')
        break
      case 'warning':
        this.callStatusTarget.classList.add('bg-yellow-100', 'text-yellow-800')
        break
      default:
        this.callStatusTarget.classList.add('bg-blue-100', 'text-blue-800')
    }
  }

  // Helper method to show errors
  showError(message) {
    this.showStatus(message, 'error')
  }
} 