import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "currentTeam",
    "availableAssociates",
    "associateCard",
    "searchInput",
    "batchForm",
    "associateIdContainer",
    "saveButton"
  ]

  connect() {
    // Initialize drag and drop if browser supports it
    if ('draggable' in document.createElement('div')) {
      this.initDragAndDrop();
    }
    
    // Initialize counters
    this.updateCounters();
    
    // Add extra event handlers for cards that might be added dynamically
    document.addEventListener('turbo:load', () => this.initDragAndDrop());
  }

  initDragAndDrop() {
    console.log('Initializing drag and drop with', this.associateCardTargets.length, 'cards');
    this.associateCardTargets.forEach(card => {
      // Make sure we don't double-initialize
      if (card.dataset.dragInitialized === 'true') return;
      
      card.draggable = true;
      card.dataset.dragInitialized = 'true';
      
      card.addEventListener('dragstart', e => {
        console.log('Drag start', card.dataset.associateId);
        e.dataTransfer.setData('text/plain', card.dataset.associateId);
        card.classList.add('opacity-50');
      });
      
      card.addEventListener('dragend', e => {
        card.classList.remove('opacity-50');
      });
    });
    
    // Make drop areas accept drops
    [this.currentTeamTarget, this.availableAssociatesTarget].forEach(dropArea => {
      dropArea.addEventListener('dragover', e => {
        e.preventDefault();
        e.stopPropagation();
        dropArea.classList.add('bg-gray-200', 'border-dashed');
      });
      
      dropArea.addEventListener('dragleave', e => {
        e.preventDefault();
        e.stopPropagation();
        dropArea.classList.remove('bg-gray-200', 'border-dashed');
      });
      
      dropArea.addEventListener('drop', e => {
        e.preventDefault();
        e.stopPropagation();
        dropArea.classList.remove('bg-gray-200', 'border-dashed');
        
        try {
          const associateId = e.dataTransfer.getData('text/plain');
          console.log('Drop with associate ID:', associateId);
          
          if (!associateId) {
            console.error('No associate ID found in drop data');
            return;
          }
          
          const card = document.querySelector(`[data-associate-id="${associateId}"]`);
          
          if (card) {
            if (dropArea === this.currentTeamTarget && card.parentElement !== this.currentTeamTarget) {
              // Moving to current team - assign
              this.assignAssociate(associateId);
            } else if (dropArea === this.availableAssociatesTarget && card.parentElement !== this.availableAssociatesTarget) {
              // Moving to available - unassign
              this.unassignAssociate(associateId);
            }
          } else {
            console.error('Card not found for associate ID:', associateId);
          }
        } catch (error) {
          console.error('Error during drop handling:', error);
        }
      });
    });
  }

  toggleDetails(e) {
    const button = e.currentTarget;
    const details = button.nextElementSibling;
    
    if (details.classList.contains('hidden')) {
      details.classList.remove('hidden');
      button.textContent = 'Hide Details';
    } else {
      details.classList.add('hidden');
      button.textContent = 'Show Details';
    }
  }

  expandAll() {
    this.associateCardTargets.forEach(card => {
      const detailsButton = card.querySelector('button[data-action="team-management#toggleDetails"]');
      const details = card.querySelector('.associate-details');
      
      if (details.classList.contains('hidden')) {
        details.classList.remove('hidden');
        detailsButton.textContent = 'Hide Details';
      }
    });
  }

  quickAssign(e) {
    const associateId = e.currentTarget.dataset.associateId;
    this.assignAssociate(associateId);
  }

  assignAssociate(associateId) {
    // Send AJAX request to assign
    console.log('Assigning associate:', associateId);
    const formData = new FormData();
    formData.append('associate_id', associateId);
    
    const userId = window.location.pathname.match(/\/users\/(\d+)/)[1];
    
    fetch(`/users/${userId}/assign_associate.json`, {
      method: 'POST',
      body: formData,
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
        'Accept': 'application/json'
      },
      credentials: 'same-origin'
    })
    .then(response => {
      // Check if the response is JSON
      const contentType = response.headers.get('content-type');
      const isJson = contentType && contentType.indexOf('application/json') !== -1;
      
      if (response.ok) {
        console.log('Associate assigned successfully');
        
        if (isJson) {
          return response.json().then(data => {
            console.log('Assignment response:', data);
            this.updateCardAfterAssignment(associateId);
          });
        } else {
          this.updateCardAfterAssignment(associateId);
          return Promise.resolve();
        }
      } else {
        console.error('Failed to assign associate:', response.status, response.statusText);
        
        if (isJson) {
          return response.json().then(data => {
            console.error('Error details:', data);
            return Promise.reject(data);
          });
        } else {
          return response.text().then(text => {
            console.error('Response text:', text);
            return Promise.reject(new Error(text));
          });
        }
      }
    })
    .catch(error => {
      console.error('Error assigning associate:', error);
    });
  }

  updateCardAfterAssignment(associateId) {
    // Move the card to the current team area
    const card = document.querySelector(`[data-associate-id="${associateId}"]`);
    if (card) {
      // Update the card styling to match current team
      card.classList.remove('border-gray-300');
      card.classList.add('border-emerald-500');
      card.querySelector('.text-xs').className = 'text-xs bg-emerald-100 text-emerald-800 rounded-full px-2 py-1';
      card.querySelector('.text-xs').textContent = 'Team Member';
      
      // Replace the add button with remove button
      const actionButton = card.querySelector('button[data-action="team-management#quickAssign"]');
      if (actionButton) {
        const userId = window.location.pathname.match(/\/users\/(\d+)/)[1];
        const removeButton = document.createElement('button');
        removeButton.type = 'button';
        removeButton.className = 'ml-2 text-red-600 hover:text-red-800 focus:outline-none';
        removeButton.dataset.action = 'team-management#unassignAssociate';
        removeButton.dataset.associateId = associateId;
        removeButton.innerHTML = `
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
          </svg>
        `;
        actionButton.parentNode.replaceChild(removeButton, actionButton);
      }
      
      // Move the card
      this.currentTeamTarget.appendChild(card);
      
      // Hide empty placeholder if needed
      const emptyPlaceholder = document.getElementById('current-empty-placeholder');
      if (emptyPlaceholder) {
        emptyPlaceholder.style.display = 'none';
      }
      
      // Show empty placeholder for available if needed
      if (this.availableAssociatesTarget.children.length === 0) {
        const emptyPlaceholder = document.getElementById('available-empty-placeholder');
        if (emptyPlaceholder) {
          emptyPlaceholder.style.display = 'block';
        }
      }
      
      // Update counters
      this.updateCounters();
    } else {
      console.error('Card not found after successful assignment');
    }
  }

  unassignAssociate(e) {
    const associateId = e.currentTarget?.dataset.associateId || e;
    // Send AJAX request to unassign
    console.log('Unassigning associate:', associateId);
    
    const userId = window.location.pathname.match(/\/users\/(\d+)/)[1];
    
    fetch(`/users/${userId}/remove_associate.json?associate_id=${associateId}`, {
      method: 'DELETE',
      headers: {
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json'
      },
      credentials: 'same-origin'
    })
    .then(response => {
      // Check if the response is JSON
      const contentType = response.headers.get('content-type');
      const isJson = contentType && contentType.indexOf('application/json') !== -1;
      
      if (response.ok) {
        console.log('Associate unassigned successfully');
        
        if (isJson) {
          return response.json().then(data => {
            console.log('Unassignment response:', data);
            this.updateCardAfterUnassignment(associateId);
          });
        } else {
          this.updateCardAfterUnassignment(associateId);
          return Promise.resolve();
        }
      } else {
        console.error('Failed to unassign associate:', response.status, response.statusText);
        
        if (isJson) {
          return response.json().then(data => {
            console.error('Error details:', data);
            return Promise.reject(data);
          });
        } else {
          return response.text().then(text => {
            console.error('Response text:', text);
            return Promise.reject(new Error(text));
          });
        }
      }
    })
    .catch(error => {
      console.error('Error unassigning associate:', error);
    });
  }

  updateCardAfterUnassignment(associateId) {
    // Move the card to the available area
    const card = document.querySelector(`[data-associate-id="${associateId}"]`);
    if (card) {
      // Update the card styling to match available
      card.classList.remove('border-emerald-500');
      card.classList.add('border-gray-300');
      card.querySelector('.text-xs').className = 'text-xs bg-gray-100 text-gray-800 rounded-full px-2 py-1';
      card.querySelector('.text-xs').textContent = 'Available';
      
      // Replace the remove button with add button
      const removeButton = card.querySelector('button[data-action="team-management#unassignAssociate"]');
      if (removeButton) {
        const addButton = document.createElement('button');
        addButton.type = 'button';
        addButton.className = 'ml-2 text-green-600 hover:text-green-800 focus:outline-none';
        addButton.dataset.action = 'team-management#quickAssign';
        addButton.dataset.associateId = associateId;
        addButton.innerHTML = `
          <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
          </svg>
        `;
        removeButton.parentNode.replaceChild(addButton, removeButton);
      }
      
      // Move the card
      this.availableAssociatesTarget.appendChild(card);
      
      // Hide empty placeholder if needed
      const emptyPlaceholder = document.getElementById('available-empty-placeholder');
      if (emptyPlaceholder) {
        emptyPlaceholder.style.display = 'none';
      }
      
      // Show empty placeholder for current if needed
      if (this.currentTeamTarget.children.length === 0) {
        const emptyPlaceholder = document.getElementById('current-empty-placeholder');
        if (emptyPlaceholder) {
          emptyPlaceholder.style.display = 'block';
        }
      }
      
      // Update counters
      this.updateCounters();
    } else {
      console.error('Card not found after successful unassignment');
    }
  }

  searchAssociates(e) {
    const query = this.searchInputTarget.value.toLowerCase();
    const availableCards = this.availableAssociatesTarget.querySelectorAll('.associate-card');
    
    availableCards.forEach(card => {
      const name = card.dataset.associateName || '';
      const email = card.dataset.associateEmail || '';
      
      if (name.includes(query) || email.includes(query) || query === '') {
        card.style.display = '';
      } else {
        card.style.display = 'none';
      }
    });
  }

  clearSearch() {
    this.searchInputTarget.value = '';
    this.searchAssociates();
  }

  updateCounters() {
    // Count visible associate cards in each list
    const currentCount = this.currentTeamTarget.querySelectorAll('.associate-card').length;
    const availableCount = this.availableAssociatesTarget.querySelectorAll('.associate-card').length;
    
    // Update the counter displays
    document.getElementById('current-count').textContent = currentCount;
    document.getElementById('available-count').textContent = availableCount;
  }
} 