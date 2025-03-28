import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    id: Number
  }
  
  connect() {
    // Initialize the controller
    console.log("Transcript modal controller connected", this.idValue);
  }
  
  open(event) {
    event.preventDefault();
    const modal = document.getElementById('transcript-modal')
    const content = document.getElementById('transcript-content')
    const debugContent = document.getElementById('debug-content')
    
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
        // Log the data for debugging
        console.log("Transcript data received:", data);
        debugContent.textContent = JSON.stringify(data, null, 2);
        
        let transcriptHtml = '';
        
        try {
          // Check if data is a string representation of an array or object that needs parsing
          if (typeof data === 'string' && (data.startsWith('[') || data.startsWith('{'))) {
            try {
              data = JSON.parse(data);
              debugContent.textContent += "\n\nParsed from string to JSON";
            } catch (e) {
              console.log("Failed to parse string as JSON:", e);
            }
          }
          
          // Determine the data format
          if (Array.isArray(data)) {
            transcriptHtml = this.handleArrayFormat(data);
          } else if (typeof data === 'string') {
            transcriptHtml = this.handleStringFormat(data);
          } else if (typeof data === 'object' && data !== null) {
            if (data.transcript || data.text || (data.results && data.results.transcripts)) {
              transcriptHtml = this.handleObjectWithTextFormat(data);
            } else if (Array.isArray(data.segments)) {
              transcriptHtml = this.handleSegmentsFormat(data.segments);
            } else if (data[0] && typeof data[0] === 'object') {
              // Try to handle non-array objects that have numeric keys like arrays
              const dataArray = Object.values(data);
              transcriptHtml = this.handleArrayFormat(dataArray);
            } else {
              transcriptHtml = this.handleRawObjectFormat(data);
            }
          } else {
            transcriptHtml = `
              <div class="p-3 rounded-lg bg-gray-100">
                <p class="text-sm text-gray-800 whitespace-pre-wrap">${JSON.stringify(data, null, 2)}</p>
                <div class="mt-3 text-xs text-gray-500">Note: Unexpected data format. Displaying raw data.</div>
              </div>
            `;
          }
        } catch (error) {
          console.error("Error processing transcript data:", error);
          transcriptHtml = `
            <div class="bg-yellow-50 border-l-4 border-yellow-400 p-4">
              <div class="flex">
                <div class="ml-3">
                  <p class="text-sm text-yellow-700">
                    Error processing transcript: ${error.message}
                  </p>
                  <p class="text-sm text-yellow-700 mt-2">
                    Raw data displayed below:
                  </p>
                  <pre class="mt-2 text-xs text-gray-800 bg-gray-100 p-2 rounded whitespace-pre-wrap">${JSON.stringify(data, null, 2)}</pre>
                </div>
              </div>
            </div>
          `;
        }
        
        if (transcriptHtml.trim() === '') {
          transcriptHtml = `
            <div class="text-center py-4">
              <p class="text-sm text-gray-500">No transcript content available</p>
            </div>
          `;
        }
        
        content.innerHTML = transcriptHtml;
      })
      .catch(error => {
        console.error("Error fetching transcript:", error);
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
        `;
      });
  }
  
  // Handle transcript data in array format
  handleArrayFormat(data) {
    if (data.length === 0) {
      return `
        <div class="text-center py-4">
          <p class="text-sm text-gray-500">Empty transcript array received</p>
        </div>
      `;
    }
    
    let html = '';
    
    // Check if we need to extract segments from the first item
    if (data[0] && Array.isArray(data[0].segments)) {
      return this.handleSegmentsFormat(data[0].segments);
    }
    
    // Process regular array format
    data.forEach((segment, index) => {
      // Determine speaker
      let speakerName = "Unknown";
      let speakerClass = "bg-gray-100";
      
      // Check various fields that might contain speaker info
      const speakerField = segment.speaker || segment.speakerLabel || segment.speakerId || null;
      
      if (speakerField) {
        // Convert to lowercase for case-insensitive comparison
        const speakerLower = String(speakerField).toLowerCase();
        
        if (speakerLower.includes('customer') || speakerLower.includes('client') || 
            speakerLower === 'a' || speakerLower === 'speaker_a' ||
            speakerLower === 'spk_0' || speakerLower === '0') {
          speakerName = "Customer";
          speakerClass = "bg-blue-100";
        } else if (speakerLower.includes('agent') || speakerLower.includes('rep') || 
                 speakerLower.includes('sales') || speakerLower.includes('user') ||
                 speakerLower === 'b' || speakerLower === 'speaker_b' ||
                 speakerLower === 'spk_1' || speakerLower === '1') {
          speakerName = "Agent";
          speakerClass = "bg-green-100";
        } else {
          // For other values, alternate based on index
          speakerName = index % 2 === 0 ? "Customer" : "Agent";
          speakerClass = index % 2 === 0 ? "bg-blue-100" : "bg-green-100";
        }
      } else {
        // If no speaker info, alternate customer/agent based on position
        speakerName = index % 2 === 0 ? "Customer" : "Agent";
        speakerClass = index % 2 === 0 ? "bg-blue-100" : "bg-green-100";
      }
      
      // Check content fields
      const textContent = segment.text || segment.transcript || segment.content || segment.value || "No text available";
      
      html += `
        <div class="mb-4">
          <div class="text-xs font-medium text-gray-500 mb-1">${speakerName}</div>
          <div class="p-3 rounded-lg ${speakerClass}">
            <p class="text-sm text-gray-800">${textContent}</p>
          </div>
        </div>
      `;
    });
    
    return html;
  }
  
  // Handle transcript data in segments format
  handleSegmentsFormat(segments) {
    return this.handleArrayFormat(segments);
  }
  
  // Handle transcript data in string format
  handleStringFormat(data) {
    return `
      <div class="p-3 rounded-lg bg-gray-100">
        <p class="text-sm text-gray-800">${data}</p>
      </div>
    `;
  }
  
  // Handle object with text/transcript field
  handleObjectWithTextFormat(data) {
    if (data.transcript) {
      return `
        <div class="p-3 rounded-lg bg-gray-100">
          <p class="text-sm text-gray-800">${data.transcript}</p>
        </div>
      `;
    } else if (data.text) {
      return `
        <div class="p-3 rounded-lg bg-gray-100">
          <p class="text-sm text-gray-800">${data.text}</p>
        </div>
      `;
    } else if (data.results && data.results.transcripts) {
      return `
        <div class="p-3 rounded-lg bg-gray-100">
          <p class="text-sm text-gray-800">${data.results.transcripts[0]?.transcript || "No transcript available"}</p>
        </div>
      `;
    }
    
    return this.handleRawObjectFormat(data);
  }
  
  // Handle raw object display
  handleRawObjectFormat(data) {
    return `
      <div class="p-3 rounded-lg bg-gray-100">
        <p class="text-sm text-gray-800 whitespace-pre-wrap">${JSON.stringify(data, null, 2)}</p>
        <div class="mt-3 text-xs text-gray-500">Note: Unable to parse this transcript format. Displaying raw data.</div>
      </div>
    `;
  }
} 