import { Controller } from "@hotwired/stimulus"

// Email Modal Controller
// Handles viewing email details in a modal
export default class extends Controller {
  static targets = [
    "modal", "body", "subject", "directionBadge", "avatar", 
    "from", "to", "date", "readBadge", "attachments", 
    "attachmentsList", "labels", "replySection", "replyForm",
    "subjectField", "replyToField", "threadIdField"
  ]
  static values = { customerId: Number }

  connect() {
    this.currentEmailId = null
    this.boundHandleEscape = this.handleEscape.bind(this)
    document.addEventListener('keydown', this.boundHandleEscape)
  }

  disconnect() {
    document.removeEventListener('keydown', this.boundHandleEscape)
  }

  handleEscape(e) {
    if (e.key === 'Escape' && this.isOpen()) {
      this.close()
    }
  }

  get modalElement() {
    return this.hasModalTarget ? this.modalTarget : document.getElementById('email-modal')
  }

  get bodyElement() {
    return this.hasBodyTarget ? this.bodyTarget : document.querySelector('[data-email-modal-target="body"]')
  }

  get replySectionElement() {
    return this.hasReplySectionTarget ? this.replySectionTarget : document.querySelector('[data-email-modal-target="replySection"]')
  }

  get replyFormElement() {
    return this.hasReplyFormTarget ? this.replyFormTarget : document.querySelector('[data-email-modal-target="replyForm"]')
  }

  isOpen() {
    const modal = this.modalElement
    return modal && (modal.classList.contains('flex') || modal.classList.contains('active'))
  }

  open(event) {
    event.preventDefault()
    const emailId = event.currentTarget.dataset.emailId
    if (!emailId) return

    this.currentEmailId = emailId
    this.loadEmail(emailId)
    
    const modal = this.modalElement
    if (modal) {
      modal.classList.remove('hidden')
      modal.classList.add('flex', 'active')
      document.body.style.overflow = 'hidden'
    }
  }

  closeOnBackground(event) {
    if (event.target === this.modalElement) {
      this.close()
    }
  }

  close(event) {
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }
    
    const modal = this.modalElement
    if (modal) {
      modal.classList.add('hidden')
      modal.classList.remove('flex', 'active')
      document.body.style.overflow = ''
    }
    const replySection = this.replySectionElement
    if (replySection) {
      replySection.classList.add('hidden')
    }
  }

  async loadEmail(emailId) {
    this.showLoading()

    try {
      const url = `/customers/${this.customerIdValue}/emails/${emailId}.json`
      
      const response = await fetch(url, {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': this.csrfToken
        }
      })

      if (!response.ok) {
        throw new Error('Failed to load email')
      }

      const email = await response.json()
      this.renderEmail(email)

      // Mark as read if unread
      if (email.status === 'received' && !email.read_at) {
        this.markAsRead(emailId)
      }
    } catch (error) {
      console.error('Error loading email:', error)
      this.showError()
    }
  }

  showLoading() {
    const body = this.bodyElement
    if (body) {
      body.innerHTML = `
        <div class="flex items-center justify-center py-12">
          <svg class="animate-spin h-8 w-8 text-blue-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
        </div>
      `
    }
  }

  showError() {
    const body = this.bodyElement
    if (body) {
      body.innerHTML = `
        <div class="text-center py-12">
          <p class="text-red-600">Failed to load email. Please try again.</p>
        </div>
      `
    }
  }

  renderEmail(email) {
    const senderName = email.status === 'received' 
      ? (email.from_name || email.from_email) 
      : (email.to_name || email.to_email)
    const senderInitial = senderName ? senderName.charAt(0).toUpperCase() : '?'
    const avatarColor = email.status === 'received' ? 'from-purple-500 to-pink-500' : 'from-blue-500 to-cyan-500'
    const emailDate = new Date(email.sent_at || email.received_at || email.created_at)

    // Get email body with multiple fallbacks
    let emailBody = ''
    if (email.body_html && email.body_html.trim()) {
      emailBody = email.body_html
    } else if (email.body_text && email.body_text.trim()) {
      emailBody = this.escapeHtml(email.body_text).replace(/\n/g, '<br>')
    } else if (email.snippet && email.snippet.trim()) {
      emailBody = `<p class="text-gray-700">${this.escapeHtml(email.snippet)}</p>`
    } else {
      emailBody = '<p class="text-gray-500 italic">No content available</p>'
    }

    // Build thread HTML
    let threadsHtml = ''
    if (email.gmail_thread_id && email.thread_emails && email.thread_emails.length > 0) {
      threadsHtml = this.buildThreadHtml(email.thread_emails)
    }

    // Build attachments HTML
    let attachmentsHtml = ''
    if (email.attachments && email.attachments.length > 0) {
      attachmentsHtml = this.buildAttachmentsHtml(email.attachments)
    }

    const body = this.bodyElement
    if (body) {
      body.innerHTML = `
        <div class="space-y-6">
          <!-- Email Header -->
          <div>
            <h3 class="text-2xl font-bold text-gray-900 mb-4">${this.escapeHtml(email.subject || '(No Subject)')}</h3>
            <div class="flex items-start space-x-4">
              <div class="flex-shrink-0">
                <div class="h-12 w-12 rounded-full bg-gradient-to-br ${avatarColor} flex items-center justify-center text-white font-semibold">
                  ${senderInitial}
                </div>
              </div>
              <div class="flex-1">
                <div class="flex items-center justify-between">
                  <div>
                    <div class="font-semibold text-gray-900">${this.escapeHtml(senderName)}</div>
                    <div class="text-sm text-gray-600">${email.status === 'received' ? 'From' : 'To'}: ${this.escapeHtml(email.status === 'received' ? email.from_email : email.to_email)}</div>
                    <div class="text-sm text-gray-500">${emailDate.toLocaleDateString()} at ${emailDate.toLocaleTimeString()}</div>
                  </div>
                  <div class="flex items-center space-x-2">
                    <button data-action="click->email-modal#reply" class="inline-flex items-center px-3 py-1.5 bg-blue-600 text-white rounded-lg hover:bg-blue-700 text-sm font-medium">
                      <svg class="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h10a8 8 0 018 8v2M3 10l6 6m-6-6l6-6" />
                      </svg>
                      Reply
                    </button>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <!-- Email Body -->
          <div class="prose prose-sm max-w-none border-t border-gray-200 pt-6">
            ${emailBody}
          </div>

          <!-- Thread Messages -->
          ${threadsHtml}

          <!-- Attachments -->
          ${attachmentsHtml}
        </div>
      `
    }

    // Update reply form fields
    this.updateReplyForm(email)
  }

  buildThreadHtml(threadEmails) {
    return `
      <div class="mt-6 pt-6 border-t border-gray-200">
        <h4 class="text-sm font-semibold text-gray-900 mb-4">${threadEmails.length} messages in thread</h4>
        ${threadEmails.map(threadEmail => {
          const threadDate = new Date(threadEmail.sent_at || threadEmail.received_at || threadEmail.created_at)
          let threadBody = threadEmail.body_html || threadEmail.body_text || threadEmail.snippet || 'No content'
          if (threadEmail.body_text && !threadEmail.body_html) {
            threadBody = this.escapeHtml(threadEmail.body_text).replace(/\n/g, '<br>')
          }
          return `
            <div class="mb-4 pb-4 border-b border-gray-100 last:border-0">
              <div class="flex items-start justify-between mb-2">
                <div class="flex items-center space-x-2">
                  <div class="h-8 w-8 rounded-full bg-gradient-to-br ${threadEmail.status === 'received' ? 'from-purple-500 to-pink-500' : 'from-blue-500 to-cyan-500'} flex items-center justify-center text-white font-semibold text-xs">
                    ${(threadEmail.from_name || threadEmail.from_email || '?').charAt(0).toUpperCase()}
                  </div>
                  <div>
                    <div class="text-sm font-medium text-gray-900">${this.escapeHtml(threadEmail.from_name || threadEmail.from_email)}</div>
                    <div class="text-xs text-gray-500">${threadDate.toLocaleDateString()} at ${threadDate.toLocaleTimeString()}</div>
                  </div>
                </div>
              </div>
              <div class="text-sm text-gray-700 ml-10">${threadBody}</div>
            </div>
          `
        }).join('')}
      </div>
    `
  }

  buildAttachmentsHtml(attachments) {
    return `
      <div class="border-t border-gray-200 pt-6">
        <h4 class="text-sm font-semibold text-gray-900 mb-3">
          <svg class="h-5 w-5 inline-block mr-1 text-gray-500" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13" />
          </svg>
          Attachments (${attachments.length})
        </h4>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
          ${attachments.map(att => `
            <div class="flex items-center space-x-3 p-3 bg-gray-50 rounded-lg hover:bg-gray-100 transition-colors border border-gray-200">
              ${this.getFileIcon(att.content_type, att.filename)}
              <div class="flex-1 min-w-0">
                <div class="text-sm font-medium text-gray-900 truncate" title="${this.escapeHtml(att.filename)}">${this.escapeHtml(att.filename)}</div>
                <div class="flex items-center space-x-2 mt-0.5">
                  ${att.human_size ? `<span class="text-xs text-gray-500">${this.escapeHtml(att.human_size)}</span>` : ''}
                </div>
              </div>
              ${att.download_url ? `
                <a href="${att.download_url}" 
                   class="flex-shrink-0 inline-flex items-center px-3 py-1.5 text-sm font-medium text-blue-600 hover:text-blue-800 hover:bg-blue-50 rounded-lg transition-colors"
                   title="Download ${this.escapeHtml(att.filename)}">
                  <svg class="h-4 w-4 mr-1" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
                  </svg>
                  Download
                </a>
              ` : `
                <span class="text-xs text-gray-400">Not available</span>
              `}
            </div>
          `).join('')}
        </div>
      </div>
    `
  }

  getFileIcon(contentType, filename) {
    const type = contentType || ''
    const name = filename || ''
    
    // PDF
    if (type.includes('pdf') || name.toLowerCase().endsWith('.pdf')) {
      return `<svg class="h-8 w-8 text-red-500 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 21h10a2 2 0 002-2V9.414a1 1 0 00-.293-.707l-5.414-5.414A1 1 0 0012.586 3H7a2 2 0 00-2 2v14a2 2 0 002 2z" />
      </svg>`
    }
    
    // Images
    if (type.startsWith('image/')) {
      return `<svg class="h-8 w-8 text-green-500 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" />
      </svg>`
    }
    
    // Word documents
    if (type.includes('word') || type.includes('document') || name.match(/\.(doc|docx)$/i)) {
      return `<svg class="h-8 w-8 text-blue-600 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
      </svg>`
    }
    
    // Spreadsheets
    if (type.includes('excel') || type.includes('spreadsheet') || name.match(/\.(xls|xlsx|csv)$/i)) {
      return `<svg class="h-8 w-8 text-green-600 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 10h18M3 14h18m-9-4v8m-7 0h14a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" />
      </svg>`
    }
    
    // Default document icon
    return `<svg class="h-8 w-8 text-blue-500 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
    </svg>`
  }

  updateReplyForm(email) {
    const subjectField = document.querySelector('[data-email-modal-target="subjectField"]')
    if (subjectField) {
      const originalSubject = email.subject || '(No Subject)'
      subjectField.value = originalSubject.startsWith('Re: ') ? originalSubject : `Re: ${originalSubject}`
    }

    const replyToField = document.querySelector('[data-email-modal-target="replyToField"]')
    if (replyToField && email.message_id) {
      replyToField.value = email.message_id
    }

    const threadIdField = document.querySelector('[data-email-modal-target="threadIdField"]')
    if (threadIdField && email.gmail_thread_id) {
      threadIdField.value = email.gmail_thread_id
    }

    const replyForm = this.replyFormElement
    if (replyForm) {
      replyForm.action = `/customers/${this.customerIdValue}/emails`
    }
  }

  reply() {
    const replySection = this.replySectionElement
    if (replySection) {
      replySection.classList.remove('hidden')
      replySection.scrollIntoView({ behavior: 'smooth' })
    }
  }

  closeReply(event) {
    event.preventDefault()
    const replySection = this.replySectionElement
    if (replySection) {
      replySection.classList.add('hidden')
    }
  }

  async submitReply(event) {
    event.preventDefault()

    const form = event.target
    const formData = new FormData(form)
    const submitButton = form.querySelector('button[type="submit"]')

    // Disable submit button
    submitButton.disabled = true
    const originalHtml = submitButton.innerHTML
    submitButton.innerHTML = `
      <svg class="animate-spin h-4 w-4 inline mr-2" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      Sending...
    `

    try {
      const response = await fetch(form.action, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': this.csrfToken,
          'Accept': 'application/json'
        },
        body: formData
      })

      const data = await response.json()

      if (data.success) {
        form.querySelector('textarea[name="body"]').value = ''
        const replySection = this.replySectionElement
        if (replySection) replySection.classList.add('hidden')
        this.loadEmail(this.currentEmailId)
        alert('Reply sent successfully!')
      } else {
        alert(data.error || 'Failed to send reply')
      }
    } catch (error) {
      console.error('Error sending reply:', error)
      alert('Failed to send reply. Please try again.')
    } finally {
      submitButton.disabled = false
      submitButton.innerHTML = originalHtml
    }
  }

  async markAsRead(emailId) {
    try {
      await fetch(`/customers/${this.customerIdValue}/emails/${emailId}/mark_as_read`, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': this.csrfToken,
          'Accept': 'application/json'
        }
      })

      // Update UI
      const emailRow = document.querySelector(`[data-email-id="${emailId}"]`)
      if (emailRow) {
        emailRow.classList.remove('bg-blue-50', 'border-l-4', 'border-blue-500', 'border-blue-200')
        emailRow.classList.add('bg-white')
        emailRow.dataset.unread = 'false'

        const unreadBadge = emailRow.querySelector('.unread-badge, [class*="bg-blue-100"]')
        if (unreadBadge && unreadBadge.textContent.trim() === 'New') {
          unreadBadge.remove()
        }
      }
    } catch (error) {
      console.error('Error marking as read:', error)
    }
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }

  escapeHtml(text) {
    if (!text) return ''
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}
