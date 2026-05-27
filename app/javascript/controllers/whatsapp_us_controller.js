import { Controller } from "@hotwired/stimulus"

// Twilio-backed "WhatsApp US" chat. Lists messages from whatsapp_messages and
// sends freeform replies. The composer is disabled unless the customer's last
// inbound message is within the 24-hour reply window.
export default class extends Controller {
  static values = { customerId: Number, windowOpen: Boolean }
  static targets = ["messagesContainer", "messagesArea", "form", "input", "sendButton", "closedNotice", "error",
                    "fileInput", "filePreview", "fileName", "attachButton"]

  connect() {
    this.applyWindowState(this.windowOpenValue)
    this.loadMessages()
    this.poll = setInterval(() => this.loadMessages(), 15000)
  }

  disconnect() {
    if (this.poll) clearInterval(this.poll)
  }

  get csrfToken() {
    return document.querySelector('[name="csrf-token"]')?.content || ""
  }

  async loadMessages() {
    try {
      const response = await fetch(`/customers/${this.customerIdValue}/whatsapp_us.json`, {
        headers: { Accept: "application/json", "X-CSRF-Token": this.csrfToken }
      })
      if (!response.ok) return
      const data = await response.json()
      this.renderMessages(data.messages || [])
      this.applyWindowState(data.window_open)
    } catch (e) {
      // network hiccup — keep last rendered state
    }
  }

  applyWindowState(open) {
    this.windowOpenValue = open
    if (this.hasInputTarget) this.inputTarget.disabled = !open
    if (this.hasSendButtonTarget) this.sendButtonTarget.disabled = !open
    if (this.hasAttachButtonTarget) this.attachButtonTarget.disabled = !open
    if (this.hasClosedNoticeTarget) this.closedNoticeTarget.classList.toggle("hidden", open)
    if (this.hasInputTarget) {
      this.inputTarget.placeholder = open ? "Type a message..." : "Reply window closed"
    }
  }

  openFileDialog() {
    if (this.windowOpenValue) this.fileInputTarget.click()
  }

  fileSelected() {
    const file = this.fileInputTarget.files[0]
    if (!file) return this.clearFile()
    this.fileNameTarget.textContent = `${file.name} (${this.humanSize(file.size)})`
    this.filePreviewTarget.classList.remove("hidden")
  }

  clearFile() {
    this.fileInputTarget.value = ""
    this.filePreviewTarget.classList.add("hidden")
    this.fileNameTarget.textContent = ""
  }

  humanSize(bytes) {
    if (bytes < 1024) return `${bytes} B`
    if (bytes < 1048576) return `${(bytes / 1024).toFixed(0)} KB`
    return `${(bytes / 1048576).toFixed(1)} MB`
  }

  renderMessages(messages) {
    if (!this.hasMessagesAreaTarget) return

    if (messages.length === 0) {
      this.messagesAreaTarget.innerHTML =
        `<div class="flex justify-center items-center py-8 text-gray-500 text-sm">No messages yet</div>`
      return
    }

    this.messagesAreaTarget.innerHTML = messages.map((m) => this.bubble(m)).join("")
    this.scrollToBottom()
  }

  bubble(m) {
    const outbound = m.direction === "outbound"
    const align = outbound ? "justify-end" : "justify-start"
    const color = outbound ? "bg-emerald-600 text-white" : "bg-white text-gray-900 border border-gray-200"
    const meta = outbound ? `${this.escape(m.formatted_time)} · ${this.escape(m.status || "")}` : this.escape(m.formatted_time)
    return `
      <div class="flex ${align}">
        <div class="max-w-[75%] rounded-lg px-3 py-2 shadow-sm ${color}">
          ${this.mediaMarkup(m, outbound)}
          ${m.body ? `<div class="text-sm whitespace-pre-wrap break-words">${this.escape(m.body)}</div>` : ""}
          <div class="mt-1 text-[10px] ${outbound ? "text-emerald-100" : "text-gray-400"} text-right">${meta}</div>
        </div>
      </div>`
  }

  mediaMarkup(m, outbound) {
    if (!m.media_url) return ""
    const linkColor = outbound ? "text-white underline" : "text-emerald-700 underline"
    if ((m.media_content_type || "").startsWith("image/")) {
      return `<a href="${m.media_url}" target="_blank" rel="noopener">
                <img src="${m.media_url}" class="mb-1 max-h-48 rounded-md" alt="attachment" />
              </a>`
    }
    return `<a href="${m.media_url}" target="_blank" rel="noopener" class="mb-1 flex items-center gap-1 text-sm ${linkColor}">
              <svg class="h-4 w-4 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
              </svg>
              <span class="truncate">${this.escape(m.media_filename || "Document")}</span>
            </a>`
  }

  async sendMessage(event) {
    event.preventDefault()
    if (!this.windowOpenValue) return

    const body = this.inputTarget.value.trim()
    const file = this.hasFileInputTarget ? this.fileInputTarget.files[0] : null
    if (!body && !file) return

    this.sendButtonTarget.disabled = true
    this.hideError()

    // multipart when a file is attached, JSON otherwise.
    const headers = { Accept: "application/json", "X-CSRF-Token": this.csrfToken }
    let payload
    if (file) {
      payload = new FormData()
      payload.append("file", file)
      if (body) payload.append("body", body)
    } else {
      headers["Content-Type"] = "application/json"
      payload = JSON.stringify({ body })
    }

    try {
      const response = await fetch(`/customers/${this.customerIdValue}/whatsapp_us`, {
        method: "POST",
        headers,
        body: payload
      })
      const data = await response.json()

      if (response.ok && data.success) {
        this.inputTarget.value = ""
        this.clearFile()
        this.loadMessages()
      } else {
        this.showError(data.error || "Failed to send message")
        if (response.status === 403) this.applyWindowState(false)
      }
    } catch (e) {
      this.showError("Network error — please try again")
    } finally {
      this.sendButtonTarget.disabled = !this.windowOpenValue
    }
  }

  showError(message) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }

  hideError() {
    if (this.hasErrorTarget) this.errorTarget.classList.add("hidden")
  }

  scrollToBottom() {
    if (this.hasMessagesContainerTarget) {
      this.messagesContainerTarget.scrollTop = this.messagesContainerTarget.scrollHeight
    }
  }

  escape(str) {
    const div = document.createElement("div")
    div.textContent = str == null ? "" : String(str)
    return div.innerHTML
  }
}
