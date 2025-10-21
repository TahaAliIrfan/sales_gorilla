// Twilio Client for browser-based calling
document.addEventListener('turbo:load', function() {
  // Check if we're on the Twilio page
  if (!document.getElementById('call-button')) return;
  
  // DOM elements
  const callButton = document.getElementById('call-button');
  const hangupButton = document.getElementById('hangup-button');
  const phoneNumberInput = document.getElementById('phone-number');
  const callStatus = document.getElementById('call-status');
  const statusMessage = document.getElementById('status-message');
  const callControls = document.getElementById('call-controls');
  const dtmfButtons = document.querySelectorAll('.dtmf');
  
  // Recording elements
  const refreshRecordingsButton = document.getElementById('refresh-recordings');
  const recordingsLoading = document.getElementById('recordings-loading');
  const noRecordings = document.getElementById('no-recordings');
  const recordingsList = document.getElementById('recordings-list');
  const recordingsTableBody = document.getElementById('recordings-table-body');
  const recordingPlayer = document.getElementById('recording-player');
  const audioPlayer = document.getElementById('audio-player');
  
  // Twilio Device and Call
  let device;
  let currentCall = null;
  
  // Initialize the Twilio Device
  function setupDevice() {
    // Show status
    callStatus.classList.remove('hidden');
    statusMessage.textContent = 'Requesting access token...';
    
    // Fetch token from our server
    fetch('/twilio/token')
      .then(response => {
        if (!response.ok) {
          throw new Error(`HTTP error! Status: ${response.status}`);
        }
        return response.json();
      })
      .then(data => {
        // Support both old and new token response formats
        const token = data.data?.token || data.token;

        if (!token) {
          throw new Error('No token received from server');
        }

        statusMessage.textContent = 'Initializing device...';
        console.log('Token received, initializing device...');

        // Initialize the Twilio Voice Device with Voice SDK 2.x
        if (!window.Twilio || !window.Twilio.Device) {
          throw new Error('Twilio Voice SDK not loaded properly');
        }

        device = new window.Twilio.Device(token, {
          logLevel: 1, // 0=silent, 1=errors, 2=warnings, 3=info, 4=debug
          codecPreferences: ['opus', 'pcmu']
        });
        
        // Setup event listeners for the device
        setupDeviceListeners();
        
        statusMessage.textContent = 'Ready to make calls';
        setTimeout(() => {
          callStatus.classList.add('hidden');
        }, 3000);
      })
      .catch(error => {
        console.error('Error setting up Twilio device:', error);
        statusMessage.textContent = `Error initializing device: ${error.message}`;
        callStatus.classList.remove('bg-blue-100', 'text-blue-800');
        callStatus.classList.add('bg-red-100', 'text-red-800');
      });
  }
  
  // Set up event listeners for the Twilio Device
  function setupDeviceListeners() {
    device.on('registered', function() {
      console.log('Device registered and ready');
    });
    
    device.on('unregistered', function() {
      console.log('Device unregistered');
    });
    
    device.on('error', function(error) {
      console.error('Device Error:', error);
      let errorMessage = 'Error: ';
      
      switch(error.code) {
        case 31000:
          errorMessage += 'Missing or invalid WebRTC requirements';
          break;
        case 31002:
          errorMessage += 'Error with capability token. Check your Twilio credentials and TwiML app configuration.';
          break;
        case 31003:
          errorMessage += 'Error registering with Twilio. Check your network connection.';
          break;
        case 31005:
          errorMessage += 'Microphone access denied. Please allow microphone access.';
          break;
        case 31008:
          errorMessage += 'Connection to Twilio failed. Check your network connection.';
          break;
        case 31009:
          errorMessage += 'Call failed - the number may be invalid or unreachable.';
          break;
        default:
          errorMessage += error.message || 'Unknown error';
      }
      
      statusMessage.textContent = errorMessage;
      callStatus.classList.remove('hidden');
      callStatus.classList.remove('bg-blue-100', 'text-blue-800');
      callStatus.classList.add('bg-red-100', 'text-red-800');
    });
    
    device.on('incoming', function(call) {
      console.log('Incoming call:', call);
      // Handle incoming call logic here if needed
    });
  }
  
  // Set up call event listeners
  function setupCallListeners() {
    if (!currentCall) return;
    
    currentCall.on('accept', function() {
      console.log('Call accepted');
      statusMessage.textContent = 'Call in progress...';
      callStatus.classList.remove('hidden');
      callStatus.classList.remove('bg-blue-100', 'text-blue-800', 'bg-red-100', 'text-red-800');
      callStatus.classList.add('bg-green-100', 'text-green-800');
      
      // Show call controls
      callControls.classList.remove('hidden');
    });
    
    currentCall.on('disconnect', function() {
      console.log('Call disconnected');
      currentCall = null;
      statusMessage.textContent = 'Call ended';
      callStatus.classList.remove('hidden');
      callStatus.classList.remove('bg-green-100', 'text-green-800', 'bg-red-100', 'text-red-800');
      callStatus.classList.add('bg-blue-100', 'text-blue-800');
      
      // Hide call controls
      callControls.classList.add('hidden');
      
      // Hide status after a delay
      setTimeout(() => {
        callStatus.classList.add('hidden');
      }, 3000);
      
      // Refresh recordings after call ends (with a delay to allow processing)
      setTimeout(fetchRecordings, 5000);
    });
    
    currentCall.on('error', function(error) {
      console.error('Call error:', error);
      statusMessage.textContent = 'Error: ' + (error.message || 'Call failed');
      callStatus.classList.remove('bg-blue-100', 'text-blue-800');
      callStatus.classList.add('bg-red-100', 'text-red-800');
      callControls.classList.add('hidden');
    });
    
    currentCall.on('cancel', function() {
      console.log('Call cancelled');
      currentCall = null;
      statusMessage.textContent = 'Call cancelled';
      callControls.classList.add('hidden');
    });
    
    currentCall.on('reject', function() {
      console.log('Call rejected');
      currentCall = null;
      statusMessage.textContent = 'Call rejected';
      callControls.classList.add('hidden');
    });
  }
  
  // Make an outgoing call
  async function makeCall() {
    const phoneNumber = phoneNumberInput.value.trim();
    
    if (!phoneNumber) {
      statusMessage.textContent = 'Please enter a phone number';
      callStatus.classList.remove('hidden');
      callStatus.classList.remove('bg-blue-100', 'text-blue-800', 'bg-green-100', 'text-green-800', 'bg-red-100', 'text-red-800');
      callStatus.classList.add('bg-yellow-100', 'text-yellow-800');
      return;
    }
    
    // Update UI
    statusMessage.textContent = 'Calling ' + phoneNumber + '...';
    callStatus.classList.remove('hidden');
    callStatus.classList.remove('bg-yellow-100', 'text-yellow-800', 'bg-red-100', 'text-red-800', 'bg-green-100', 'text-green-800');
    callStatus.classList.add('bg-blue-100', 'text-blue-800');
    
    // Make the call
    const params = {
      To: phoneNumber,
      phone_number: '+447897021964'
    };
    
    console.log('Making call with params:', params);
    
    if (device) {
      try {
        // Use Voice SDK 2.x API - device.connect() returns a Promise<Call>
        currentCall = await device.connect({
          params: params
        });
        
        // Set up call event listeners
        setupCallListeners();
        
        statusMessage.textContent = 'Call connecting...';
        
      } catch (error) {
        console.error('Error connecting call:', error);
        statusMessage.textContent = 'Error connecting call: ' + error.message;
        callStatus.classList.remove('bg-blue-100', 'text-blue-800');
        callStatus.classList.add('bg-red-100', 'text-red-800');
      }
    } else {
      statusMessage.textContent = 'Device not initialized. Please refresh the page.';
      callStatus.classList.remove('bg-blue-100', 'text-blue-800');
      callStatus.classList.add('bg-red-100', 'text-red-800');
    }
  }
  
  // Hang up the current call
  function hangUp() {
    if (currentCall) {
      currentCall.disconnect();
    }
  }
  
  // Send DTMF tones
  function sendDigit(digit) {
    if (currentCall) {
      currentCall.sendDigits(digit);
    }
  }
  
  // Fetch call recordings from the server
  function fetchRecordings() {
    // Show loading state
    recordingsLoading.classList.remove('hidden');
    noRecordings.classList.add('hidden');
    recordingsList.classList.add('hidden');
    recordingPlayer.classList.add('hidden');
    
    // Fetch recordings from our server
    fetch('/twilio/recordings')
      .then(response => {
        if (!response.ok) {
          throw new Error(`HTTP error! Status: ${response.status}`);
        }
        return response.json();
      })
      .then(recordings => {
        // Hide loading state
        recordingsLoading.classList.add('hidden');
        
        // Clear existing recordings
        recordingsTableBody.innerHTML = '';
        
        if (recordings.length === 0) {
          // Show no recordings message
          noRecordings.classList.remove('hidden');
        } else {
          // Show recordings list
          recordingsList.classList.remove('hidden');
          
          // Add recordings to the table
          recordings.forEach(recording => {
            const row = document.createElement('tr');
            row.className = 'border-b border-gray-200 hover:bg-gray-100';
            
            // Format date
            const date = new Date(recording.date);
            const formattedDate = date.toLocaleString();
            
            // Format duration (seconds to MM:SS)
            const minutes = Math.floor(recording.duration / 60);
            const seconds = recording.duration % 60;
            const formattedDuration = `${minutes.toString().padStart(2, '0')}:${seconds.toString().padStart(2, '0')}`;
            
            row.innerHTML = `
              <td class="py-3 px-4">${formattedDate}</td>
              <td class="py-3 px-4">${formattedDuration}</td>
              <td class="py-3 px-4">
                <button class="play-recording bg-blue-500 hover:bg-blue-600 text-white px-3 py-1 rounded text-xs mr-2" 
                        data-url="${recording.url}">
                  <i class="fas fa-play"></i> Play
                </button>
                <a href="${recording.url}" download class="bg-gray-500 hover:bg-gray-600 text-white px-3 py-1 rounded text-xs">
                  <i class="fas fa-download"></i> Download
                </a>
              </td>
            `;
            
            recordingsTableBody.appendChild(row);
          });
          
          // Add event listeners to play buttons
          document.querySelectorAll('.play-recording').forEach(button => {
            button.addEventListener('click', function() {
              const url = this.getAttribute('data-url');
              playRecording(url);
            });
          });
        }
      })
      .catch(error => {
        console.error('Error fetching recordings:', error);
        recordingsLoading.classList.add('hidden');
        noRecordings.classList.remove('hidden');
        noRecordings.querySelector('p').textContent = `Error loading recordings: ${error.message}`;
      });
  }
  
  // Play a recording
  function playRecording(url) {
    // Show the player
    recordingPlayer.classList.remove('hidden');
    
    // Set the audio source and play
    audioPlayer.src = url;
    audioPlayer.play().catch(error => {
      console.error('Error playing audio:', error);
    });
  }
  
  // Event listeners
  callButton.addEventListener('click', makeCall);
  hangupButton.addEventListener('click', hangUp);
  refreshRecordingsButton.addEventListener('click', fetchRecordings);
  
  // DTMF keypad buttons
  dtmfButtons.forEach(button => {
    button.addEventListener('click', function() {
      const digit = this.getAttribute('data-digit');
      sendDigit(digit);
    });
  });
  
  // Initialize the device when the page loads
  setupDevice();
  
  // Fetch recordings when the page loads
  fetchRecordings();
}); 