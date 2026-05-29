import { Controller } from "@hotwired/stimulus"

// Twilio-backed "WhatsApp US" chat. Lists messages from whatsapp_messages and
// sends freeform replies. The composer is disabled unless the customer's last
// inbound message is within the 24-hour reply window.
export default class extends Controller {
  static values = { customerId: Number, windowOpen: Boolean, isAdmin: Boolean, customerFields: Object }
  static targets = ["messagesContainer", "messagesArea", "form", "input", "sendButton", "closedNotice", "error",
                    "fileInput", "filePreview", "fileName", "attachButton",
                    "templateModal", "templateList", "templateError", "templateNotice", "syncButton"]

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

  // ---- Templates ----------------------------------------------------------

  openTemplatePicker() {
    this.templateModalTarget.classList.remove("hidden")
    this.hideTemplateError()
    this.hideTemplateNotice()
    this.loadTemplates()
  }

  closeTemplatePicker() {
    this.templateModalTarget.classList.add("hidden")
  }

  async loadTemplates() {
    this.templateListTarget.innerHTML =
      `<div class="flex justify-center items-center py-8 text-gray-500 text-sm">Loading templates...</div>`
    try {
      const res = await fetch(`/customers/${this.customerIdValue}/whatsapp_us/templates`, {
        headers: { Accept: "application/json", "X-CSRF-Token": this.csrfToken }
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || "Failed to load templates")
      this.renderTemplates(data.templates || [])
    } catch (e) {
      this.showTemplateError(e.message || "Failed to load templates")
    }
  }

  async syncTemplates() {
    if (!this.hasSyncButtonTarget) return
    this.syncButtonTarget.disabled = true
    this.hideTemplateError()
    this.hideTemplateNotice()
    try {
      const res = await fetch(`/customers/${this.customerIdValue}/whatsapp_us/templates/sync`, {
        method: "POST",
        headers: { Accept: "application/json", "X-CSRF-Token": this.csrfToken }
      })
      const data = await res.json()
      if (!res.ok || !data.success) throw new Error(data.error || "Sync failed")
      this.showTemplateNotice(`Synced ${data.synced} approved template(s) (skipped ${data.skipped}).`)
      this.renderTemplates(data.templates || [])
    } catch (e) {
      this.showTemplateError(e.message || "Sync failed")
    } finally {
      this.syncButtonTarget.disabled = false
    }
  }

  renderTemplates(templates) {
    if (templates.length === 0) {
      this.templateListTarget.innerHTML = `
        <div class="text-center py-8 text-gray-500 text-sm">
          No approved templates yet.${this.isAdminValue ? " Click \"Sync from Twilio\" to fetch them." : ""}
        </div>`
      return
    }

    this.templateListTarget.innerHTML = templates.map((t) => this.templateCard(t)).join("")
  }

  templateCard(t) {
    // Only render inputs for text variables — media variables are filled from
    // the uploaded file's signed URL on the server.
    const textKeys = t.text_variable_keys || t.variable_keys || []
    const vars = textKeys.map((k) => this.variableRow(k)).join("")

    const mediaInput = t.has_media ? `
      <div class="mt-2">
        <label class="block text-xs font-medium text-gray-600 mb-1">Attach file <span class="text-red-500">*</span></label>
        <input type="file" data-template-file="true"
               accept="image/*,video/mp4,audio/*,.pdf,.doc,.docx,.xls,.xlsx,.pptx,.txt,.csv,.json,.xml,.zip"
               class="block w-full text-xs text-gray-700 file:mr-3 file:py-1.5 file:px-3 file:rounded-md file:border file:border-gray-300 file:bg-white file:text-gray-700 file:hover:bg-gray-50 file:text-xs file:font-medium" />
        <p class="mt-1 text-[11px] text-gray-500">This template requires a media attachment. Max 16MB.</p>
      </div>` : ""

    return `
      <div class="border border-gray-200 rounded-md p-3 mb-3" data-template-sid="${this.escape(t.content_sid)}">
        <div class="flex items-start justify-between gap-3">
          <div class="min-w-0">
            <div class="text-sm font-semibold text-gray-900 truncate">
              ${this.escape(t.friendly_name || t.content_sid)}
              ${t.has_media ? `<span class="ml-1 inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-medium bg-blue-100 text-blue-700">MEDIA</span>` : ""}
            </div>
            <div class="text-[11px] text-gray-500 mt-0.5">
              ${this.escape(t.language || "")}${t.category ? " · " + this.escape(t.category) : ""}
            </div>
          </div>
          <button type="button" data-action="click->whatsapp-us#sendTemplate"
                  class="inline-flex items-center px-3 py-1.5 border border-transparent text-xs font-medium rounded-md text-white bg-emerald-600 hover:bg-emerald-700 flex-shrink-0">
            Send
          </button>
        </div>
        ${t.body ? `<div class="mt-2 text-sm text-gray-700 bg-gray-50 border border-gray-200 rounded-md px-2 py-1.5 whitespace-pre-wrap break-words">${this.escape(t.body)}</div>` : ""}
        ${mediaInput}
        ${vars}
      </div>`
  }

  async sendTemplate(event) {
    const card = event.currentTarget.closest("[data-template-sid]")
    if (!card) return

    const contentSid = card.dataset.templateSid
    const variables = {}
    card.querySelectorAll("input[data-var-key]").forEach((el) => {
      if (el.value.trim()) variables[el.dataset.varKey] = el.value.trim()
    })

    const fileInput = card.querySelector('input[data-template-file="true"]')
    const file = fileInput?.files?.[0] || null
    if (fileInput && !file) {
      this.showTemplateError("This template requires a file attachment.")
      return
    }

    const btn = event.currentTarget
    btn.disabled = true
    this.hideTemplateError()

    try {
      // multipart when uploading a file, JSON otherwise.
      const headers = { Accept: "application/json", "X-CSRF-Token": this.csrfToken }
      let payload
      if (file) {
        payload = new FormData()
        payload.append("content_sid", contentSid)
        payload.append("file", file)
        Object.entries(variables).forEach(([k, v]) => payload.append(`variables[${k}]`, v))
      } else {
        headers["Content-Type"] = "application/json"
        payload = JSON.stringify({ content_sid: contentSid, variables })
      }

      const res = await fetch(`/customers/${this.customerIdValue}/whatsapp_us/send_template`, {
        method: "POST",
        headers,
        body: payload
      })
      const data = await res.json()
      if (!res.ok || !data.success) throw new Error(data.error || "Failed to send template")
      this.closeTemplatePicker()
      this.loadMessages()
    } catch (e) {
      this.showTemplateError(e.message || "Failed to send template")
    } finally {
      btn.disabled = false
    }
  }

  showTemplateError(message) {
    if (!this.hasTemplateErrorTarget) return
    this.templateErrorTarget.textContent = message
    this.templateErrorTarget.classList.remove("hidden")
  }
  hideTemplateError() {
    if (this.hasTemplateErrorTarget) this.templateErrorTarget.classList.add("hidden")
  }
  showTemplateNotice(message) {
    if (!this.hasTemplateNoticeTarget) return
    this.templateNoticeTarget.textContent = message
    this.templateNoticeTarget.classList.remove("hidden")
  }
  hideTemplateNotice() {
    if (this.hasTemplateNoticeTarget) this.templateNoticeTarget.classList.add("hidden")
  }
}
