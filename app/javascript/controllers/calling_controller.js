import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "callButton",
    "hangupButton",
    "phoneNumber",
    "callerId",
    "customerSelect",
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
    "audioPlayer",
    "customerFilter",
    "userFilter",
    "dateFromFilter",
    "dateToFilter"
  ]

  // Token can be rendered into the page by the server (zero round-trip path)
  // via `data-calling-token-value="..."`. Empty string => fetch fallback.
  static values = { token: String }

  connect() {
    this.device = null
    this.currentCall = null
    this.setupDevice()
    this.fetchRecordings()
    this.updateCallButtonState()
  }

  // Handle customer selection
  onCustomerSelect(event) {
    const selectedOption = event.target.selectedOptions[0]
    const phone = selectedOption.dataset.phone || ''
    
    this.phoneNumberTarget.value = phone
    this.phoneNumberTarget.readOnly = true
    
    if (!phone) {
      this.showStatus('Unable to call customer as it has no phone number. Please add a number to the customer profile.', 'warning')
      this.callButtonTarget.disabled = true
      this.callButtonTarget.classList.add('opacity-50', 'cursor-not-allowed')
    } else {
      this.callStatusTarget.classList.add('hidden')
      this.callButtonTarget.disabled = false
      this.callButtonTarget.classList.remove('opacity-50', 'cursor-not-allowed')
    }
  }

  // Handle direct phone number input
  onPhoneNumberInput(event) {
    const phoneNumber = event.target.value.trim()
    
    // When user types in phone number, clear customer selection and make field editable
    if (phoneNumber && this.customerSelectTarget.value) {
      this.customerSelectTarget.value = ''
    }
    this.phoneNumberTarget.readOnly = false
    
    // Update call button state
    this.updateCallButtonState()
  }

  // Filter customers based on search input
  filterCustomers(event) {
    const searchTerm = event.target.value.trim().toLowerCase()
    const options = this.customerSelectTarget.options
    
    // Show all options if search term is empty
    if (!searchTerm) {
      for (let i = 0; i < options.length; i++) {
        options[i].style.display = ''
      }
      return
    }
    
    // Hide options that don't match the search term
    let visibleCount = 0
    for (let i = 0; i < options.length; i++) {
      const option = options[i]
      const customerName = option.dataset.customerName || ''
      
      if (i === 0 || customerName.includes(searchTerm)) {
        option.style.display = ''
        visibleCount++
      } else {
        option.style.display = 'none'
      }
    }
    
    // Show a message if no customers match the search
    if (visibleCount <= 1) {
      this.showStatus(`No customers found matching "${searchTerm}"`, 'info')
    } else {
      this.callStatusTarget.classList.add('hidden')
    }
  }

  // Update call button state based on phone number
  updateCallButtonState() {
    const phoneNumber = this.phoneNumberTarget.value.trim()
    const customerSelected = this.customerSelectTarget.value !== ''
    
    // Allow calling with just phone number OR with customer selection
    if (phoneNumber && (customerSelected || this.isValidPhoneNumber(phoneNumber))) {
      this.callButtonTarget.disabled = false
      this.callButtonTarget.classList.remove('opacity-50', 'cursor-not-allowed')
      this.callStatusTarget.classList.add('hidden')
    } else {
      this.callButtonTarget.disabled = true
      this.callButtonTarget.classList.add('opacity-50', 'cursor-not-allowed')
      
      if (customerSelected && !phoneNumber) {
        this.showStatus('Unable to call customer as it has no phone number. Please add a number to the customer profile.', 'warning')
      }
    }
  }

  // Basic phone number validation (country code format)
  isValidPhoneNumber(phoneNumber) {
    return /^\+\d{6,15}$/.test(phoneNumber)
  }

  // Initialize the Twilio Device. Prefers the server-embedded token
  // (data-calling-token-value) so there's no /calling/token round trip on
  // page load. Falls back to fetch if the value is missing or unusable.
  async setupDevice() {
    this.showStatus('Connecting…')

    try {
      let token = this.hasTokenValue && this.tokenValue ? this.tokenValue : null
      if (!token) {
        const response = await fetch('/calling/token')
        if (!response.ok) {
          throw new Error(`HTTP error! Status: ${response.status}`)
        }
        const data = await response.json()
        token = data.data?.token || data.token
      }

      if (!token) {
        throw new Error('No token received from server')
      }

      // Wait for the Twilio Voice SDK to be available (the <script> tag is at
      // the bottom of the page; on Turbo navigations it may not be parsed
      // before connect() fires).
      await this.waitForTwilioSdk()

      this.device = new window.Twilio.Device(token, {
        logLevel: 1, // 0=silent, 1=errors, 2=warnings, 3=info, 4=debug
        codecPreferences: ['opus', 'pcmu']
      })

      this.setupDeviceListeners()

      // Quietly mark ready and dismiss the banner promptly.
      this.showStatus('Ready', 'success')
      setTimeout(() => {
        this.callStatusTarget.classList.add('hidden')
      }, 800)
    } catch (error) {
      console.error('Error setting up device:', error)
      this.showError(`Unable to initialize phone service: ${error.message}. Please refresh the page or contact support.`)
    }
  }

  // Resolves once window.Twilio.Device is defined, polling lightly. Caps
  // wait at ~5s to surface a clear error if the CDN is unreachable.
  async waitForTwilioSdk(timeoutMs = 5000) {
    if (window.Twilio?.Device) return
    const start = Date.now()
    while (!window.Twilio?.Device) {
      if (Date.now() - start > timeoutMs) {
        throw new Error('Twilio Voice SDK failed to load')
      }
      await new Promise((r) => setTimeout(r, 50))
    }
  }

  // Set up event listeners for the Twilio Device
  setupDeviceListeners() {
    // Device registered (ready to make calls)
    this.device.on('registered', () => {
      console.log('Device registered and ready')
    })
    
    this.device.on('unregistered', () => {
      console.log('Device unregistered')
    })
    
    this.device.on('error', (error) => {
      console.error('Device Error:', error)
      let errorMessage = 'Error: '
      
      switch(error.code) {
        case 31000:
          errorMessage += 'Missing or invalid browser requirements for making calls'
          break
        case 31002:
          errorMessage += 'Authentication error. Please refresh the page or contact support.'
          break
        case 31003:
          errorMessage += 'Error connecting to phone service. Check your network connection.'
          break
        case 31005:
          errorMessage += 'Microphone access denied. Please allow microphone access in your browser settings.'
          break
        case 31008:
          errorMessage += 'Connection to phone service failed. Check your network connection.'
          break
        case 31009:
          errorMessage += 'Call failed - the number may be invalid or unreachable.'
          break
        default:
          errorMessage += error.message || 'Unknown error'
      }
      
      this.showError(errorMessage)
    })
    
    // Handle incoming calls (if supported)
    this.device.on('incoming', (call) => {
      console.log('Incoming call:', call)
      // Handle incoming call logic here if needed
    })
  }

  // Make an outgoing call
  async makeCall(event) {
    event.preventDefault()
    const phoneNumber = this.phoneNumberTarget.value.trim()
    const callerId = this.callerIdTarget.value
    let customerId = this.customerSelectTarget.value
    
    if (!phoneNumber) {
      this.showStatus('Please enter a phone number', 'warning')
      return
    }

    // If no customer is selected, create one automatically
    if (!customerId) {
      if (!this.isValidPhoneNumber(phoneNumber)) {
        this.showStatus('Please enter a valid phone number with country code (e.g. +923001234567)', 'warning')
        return
      }
      
      this.showStatus('Creating customer and calling...', 'info')
      
      try {
        customerId = await this.createCustomerFromPhoneNumber(phoneNumber)
        if (!customerId) {
          this.showError('Failed to create customer. Please try again.')
          return
        }
      } catch (error) {
        console.error('Error creating customer:', error)
        this.showError('Failed to create customer: ' + error.message)
        return
      }
    }
    
    this.showStatus(`Calling ${phoneNumber}...`, 'info')
    
    try {
      // Store the customer ID in the session for recording association
      fetch('/calling/store_customer_id', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ customer_id: customerId })
      }).catch(error => {
        console.error('Error storing customer ID:', error)
      })
      
      const params = {
        To: phoneNumber,
        caller_id: callerId,
        customer_id: customerId
      }
      
      console.log('Making call with params:', params)
      
      if (this.device) {
        try {
          // Use Voice SDK 2.x API - device.connect() returns a Promise<Call>
          this.currentCall = await this.device.connect({
            params: params
          })
          
          // Set up call event listeners
          this.setupCallListeners()
          
          this.showStatus('Call connecting...', 'info')
          this.callControlsTarget.classList.remove('hidden')
          
        } catch (error) {
          console.error('Error connecting call:', error)
          this.showError('Error connecting call: ' + error.message)
        }
      } else {
        this.showError('Phone service not initialized. Please refresh the page and try again.')
      }
    } catch (error) {
      console.error('Unexpected error during call setup:', error)
      this.showError('Unexpected error occurred. Please refresh the page and try again.')
    }
  }

  // Create a customer from phone number
  async createCustomerFromPhoneNumber(phoneNumber) {
    try {
      const response = await fetch('/customers', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({
          customer: {
            name: phoneNumber,
            phone: phoneNumber
          }
        })
      })
      
      console.log('Response status:', response.status)
      console.log('Response headers:', Object.fromEntries(response.headers.entries()))
      
      // Get the response text first to debug what we're receiving
      const responseText = await response.text()
      console.log('Response text:', responseText.substring(0, 200))
      
      if (!response.ok) {
        let errorMessage = `HTTP error! Status: ${response.status}`
        
        try {
          const errorData = JSON.parse(responseText)
          if (errorData.error) {
            errorMessage = errorData.error
          } else if (errorData.errors) {
            errorMessage = Object.values(errorData.errors).flat().join(', ')
          }
        } catch (parseError) {
          console.error('Failed to parse error response as JSON:', parseError)
          errorMessage = response.statusText || errorMessage
        }
        
        throw new Error(errorMessage)
      }
      
      // Parse the response as JSON
      const customer = JSON.parse(responseText)
      console.log('Parsed customer:', customer)
      return customer.id
    } catch (error) {
      console.error('Error creating customer:', error)
      throw error
    }
  }

  // Set up call event listeners
  setupCallListeners() {
    if (!this.currentCall) return
    
    this.currentCall.on('accept', () => {
      console.log('Call accepted')
      this.showStatus('Call in progress...', 'success')
    })
    
    this.currentCall.on('disconnect', () => {
      console.log('Call disconnected')
      this.currentCall = null
      this.showStatus('Call ended', 'info')
      this.callControlsTarget.classList.add('hidden')
      
      setTimeout(() => {
        this.callStatusTarget.classList.add('hidden')
      }, 3000)
      
      setTimeout(() => this.fetchRecordings(), 5000)
    })
    
    this.currentCall.on('error', (error) => {
      console.error('Call error:', error)
      this.showError(`Call failed: ${error.message || 'Unknown error'}. Please try again.`)
      this.callControlsTarget.classList.add('hidden')
    })
    
    this.currentCall.on('cancel', () => {
      console.log('Call cancelled')
      this.currentCall = null
      this.showStatus('Call cancelled', 'info')
      this.callControlsTarget.classList.add('hidden')
    })
    
    this.currentCall.on('reject', () => {
      console.log('Call rejected')
      this.currentCall = null
      this.showStatus('Call rejected', 'warning')
      this.callControlsTarget.classList.add('hidden')
    })
  }
  
  // Hang up the current call
  hangUp(event) {
    event.preventDefault()
    if (this.currentCall) {
      this.currentCall.disconnect()
    }
  }

  // Send DTMF tones
  sendDigit(event) {
    const digit = event.currentTarget.dataset.digit
    if (this.currentCall) {
      this.currentCall.sendDigits(digit)
    }
  }

  // Fetch call recordings from the server
  async fetchRecordings() {
    // Skip if user is not admin (check if the recordings section exists)
    if (!document.querySelector('[data-calling-target="recordingsList"]')) {
      return;
    }
    
    this.recordingsLoadingTarget.classList.remove('hidden')
    this.noRecordingsTarget.classList.add('hidden')
    this.recordingsListTarget.classList.add('hidden')
    this.recordingPlayerTarget.classList.add('hidden')
    
    try {
      // Get filter values
      const filters = this.getFilterParams()
      const queryParams = new URLSearchParams(filters).toString()
      const url = `/calling/recordings${queryParams ? '?' + queryParams : ''}`
      
      const response = await fetch(url)
      
      // If redirected due to not being admin
      if (response.redirected) {
        this.recordingsLoadingTarget.classList.add('hidden')
        this.noRecordingsTarget.classList.remove('hidden')
        this.noRecordingsTarget.innerHTML = '<p class="text-red-600">You do not have permission to view recordings.</p>'
        return
      }
      
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
      this.noRecordingsTarget.innerHTML = `<p class="text-red-600">Error loading recordings: ${error.message}</p>`
    }
  }

  // Get filter parameters
  getFilterParams() {
    const filters = {}
    
    if (this.hasCustomerFilterTarget && this.customerFilterTarget.value) {
      filters.customer_id = this.customerFilterTarget.value
    }
    
    if (this.hasUserFilterTarget && this.userFilterTarget.value) {
      filters.user_id = this.userFilterTarget.value
    }
    
    if (this.hasDateFromFilterTarget && this.dateFromFilterTarget.value) {
      filters.date_from = this.dateFromFilterTarget.value
    }
    
    if (this.hasDateToFilterTarget && this.dateToFilterTarget.value) {
      filters.date_to = this.dateToFilterTarget.value
    }
    
    return filters
  }
  
  // Apply filters to recordings
  applyFilters(event) {
    event.preventDefault()
    this.fetchRecordings()
  }
  
  // Reset all filters
  resetFilters(event) {
    event.preventDefault()
    
    if (this.hasCustomerFilterTarget) {
      this.customerFilterTarget.value = ''
    }
    
    if (this.hasUserFilterTarget) {
      this.userFilterTarget.value = ''
    }
    
    if (this.hasDateFromFilterTarget) {
      this.dateFromFilterTarget.value = ''
    }
    
    if (this.hasDateToFilterTarget) {
      this.dateToFilterTarget.value = ''
    }
    
    this.fetchRecordings()
  }

  // Render recordings in the table
  renderRecordings(recordings) {
    recordings.forEach(recording => {
      const row = document.createElement('tr')
      row.className = 'border-b border-gray-200 hover:bg-gray-100'
      
      // Format date
      const date = new Date(recording.date)
      const formattedDate = date.toLocaleString()
      
      // Format duration
      const minutes = Math.floor(recording.duration / 60)
      const seconds = recording.duration % 60
      const formattedDuration = `${minutes}:${seconds.toString().padStart(2, '0')}`
      
      // Customer info with link to customer view page
      const customerName = recording.customer_name || 'Unknown'
      const customerId = recording.customer_id
      const customerInfo = customerId ? 
        `<div class="font-medium"><a href="/customers/${customerId}" class="text-blue-600 hover:text-blue-800 hover:underline">${customerName}</a></div>` : 
        `<div class="font-medium">${customerName}</div>`
      
      // Agent info with tooltip
      const agentName = recording.user_name || 'Unknown'
      const agentInfo = `<div class="font-medium">${agentName}</div>`
      
      row.innerHTML = `
        <td class="py-3 px-4">${formattedDate}</td>
        <td class="py-3 px-4">${customerInfo}</td>
        <td class="py-3 px-4">${formattedDuration}</td>
        <td class="py-3 px-4">${agentInfo}</td>
        <td class="py-3 px-4">
          <button class="bg-blue-500 hover:bg-blue-600 text-white px-2 py-1 rounded text-xs play-recording" data-sid="${recording.sid}">
            <i class="fas fa-play"></i> Play
          </button>
        </td>
      `
      
      // Add event listener to play button
      const playButton = row.querySelector('.play-recording')
      playButton.addEventListener('click', (event) => {
        this.playRecording(event)
      })
      
      this.recordingsTableBodyTarget.appendChild(row)
    })
  }

  // Play a recording
  playRecording(event) {
    const sid = event.currentTarget.dataset.sid
    this.recordingPlayerTarget.classList.remove('hidden')
    this.audioPlayerTarget.src = `/calling/play_recording/${sid}`
    this.audioPlayerTarget.play()
  }

  // Display status messages with appropriate styling
  showStatus(message, type = 'info') {
    this.statusMessageTarget.innerHTML = ''
    
    // Create icon based on status type
    let iconSvg = ''
    let bgColor = ''
    let textColor = ''
    
    switch(type) {
      case 'success':
        iconSvg = '<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2 text-green-500" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>'
        bgColor = 'bg-green-50'
        textColor = 'text-green-800'
        break
      case 'warning':
        iconSvg = '<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2 text-yellow-500" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" /></svg>'
        bgColor = 'bg-yellow-50'
        textColor = 'text-yellow-800'
        break
      case 'error':
        iconSvg = '<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2 text-red-500" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>'
        bgColor = 'bg-red-50'
        textColor = 'text-red-800'
        break
      default: // info
        iconSvg = '<svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5 mr-2 text-indigo-500" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>'
        bgColor = 'bg-indigo-50'
        textColor = 'text-indigo-800'
    }
    
    // Set status message with icon
    this.statusMessageTarget.innerHTML = `${iconSvg}${message}`
    
    // Update the status container styling
    this.callStatusTarget.className = `${bgColor} ${textColor} p-4 rounded-lg mb-5 shadow-sm flex items-center`
    
    // Show the status message
    this.callStatusTarget.classList.remove('hidden')
  }

  // Show error message (convenience method)
  showError(message) {
    this.showStatus(message, 'error')
  }
} 