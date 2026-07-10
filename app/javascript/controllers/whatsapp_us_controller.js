import { Controller } from "@hotwired/stimulus"

// Twilio-backed "WhatsApp US" chat. Lists messages from whatsapp_messages and
// sends freeform replies. The composer is disabled unless the customer's last
// inbound message is within the 24-hour reply window.
export default class extends Controller {
  static values = { customerId: Number, windowOpen: Boolean, isAdmin: Boolean, customerFields: Object }
  static targets = ["messagesContainer", "messagesArea", "form", "input", "sendButton", "closedNotice", "error",
                    "fileInput", "filePreview", "fileName", "attachButton",
                    "templateModal", "templateList", "templateError", "templateNotice", "syncButton",
                    "syncChatButton", "syncChatLabel",
                    "unreachableBanner", "unreachableReason", "lookupButton",
                    "micButton", "recordingBar", "recordingTimer", "voicePreview", "voicePlayer", "voiceSendButton"]

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

  async syncChat() {
    if (!this.hasSyncChatButtonTarget) return

    const confirmed = window.confirm(
      "Sync from Twilio?\n\n" +
      "Heads up: Twilio retains WhatsApp message history for a limited time " +
      "(varies by account tier — typically 30–90 days), so the sync gives you " +
      "Twilio's window of memory, not all-time history. Existing local messages " +
      "are kept; new ones from Twilio are added and statuses are refreshed."
    )
    if (!confirmed) return

    this.syncChatButtonTarget.disabled = true
    const originalLabel = this.hasSyncChatLabelTarget ? this.syncChatLabelTarget.textContent : null
    if (this.hasSyncChatLabelTarget) this.syncChatLabelTarget.textContent = "Syncing…"
    this.hideError()

    try {
      const res = await fetch(`/customers/${this.customerIdValue}/whatsapp_us/sync_chat`, {
        method: "POST",
        headers: { Accept: "application/json", "X-CSRF-Token": this.csrfToken }
      })
      const data = await res.json()
      if (!res.ok || !data.success) throw new Error(data.error || "Sync failed")

      this.renderMessages(data.messages || [])
      this.applyWindowState(data.window_open)

      if (this.hasSyncChatLabelTarget) {
        const summary = `Synced ${data.synced} (+${data.created} new)`
        this.syncChatLabelTarget.textContent = summary
        setTimeout(() => {
          if (this.hasSyncChatLabelTarget) this.syncChatLabelTarget.textContent = originalLabel || "Sync"
        }, 2500)
      }
    } catch (e) {
      this.showError(e.message || "Sync failed")
      if (this.hasSyncChatLabelTarget) this.syncChatLabelTarget.textContent = originalLabel || "Sync"
    } finally {
      this.syncChatButtonTarget.disabled = false
    }
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
      this.applyReachability(data)
    } catch (e) {
      // network hiccup — keep last rendered state
    }
  }

  applyReachability(data) {
    if (!this.hasUnreachableBannerTarget) return
    if (data.phone_unreachable) {
      this.unreachableBannerTarget.classList.remove("hidden")
      if (this.hasUnreachableReasonTarget) {
        this.unreachableReasonTarget.textContent =
          data.phone_unreachable_reason ||
          "This number appears to be a disposable/VoIP line not registered on WhatsApp."
      }
      // Also disable composer — sending will only burn money.
      if (this.hasSendButtonTarget)   this.sendButtonTarget.disabled = true
      if (this.hasAttachButtonTarget) this.attachButtonTarget.disabled = true
      if (this.hasInputTarget) {
        this.inputTarget.disabled = true
        this.inputTarget.placeholder = "Number is not on WhatsApp"
      }
    } else {
      this.unreachableBannerTarget.classList.add("hidden")
    }
  }

  async lookupPhone() {
    if (!this.hasLookupButtonTarget) return
    this.lookupButtonTarget.disabled = true
    const orig = this.lookupButtonTarget.textContent
    this.lookupButtonTarget.textContent = "Checking…"
    try {
      const res = await fetch(`/customers/${this.customerIdValue}/whatsapp_us/lookup_phone`, {
        method: "POST",
        headers: { Accept: "application/json", "X-CSRF-Token": this.csrfToken }
      })
      const data = await res.json()
      if (!res.ok || !data.success) throw new Error(data.error || "Lookup failed")
      this.applyReachability(data)
      // Re-apply window state on the chance the lookup cleared the gate.
      if (!data.phone_unreachable) this.loadMessages()
    } catch (e) {
      this.showError(e.message || "Lookup failed")
    } finally {
      this.lookupButtonTarget.disabled = false
      this.lookupButtonTarget.textContent = orig
    }
  }

  applyWindowState(open) {
    this.windowOpenValue = open
    if (this.hasInputTarget) this.inputTarget.disabled = !open
    if (this.hasSendButtonTarget) this.sendButtonTarget.disabled = !open
    if (this.hasAttachButtonTarget) this.attachButtonTarget.disabled = !open
    if (this.hasMicButtonTarget) this.micButtonTarget.disabled = !open
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
    const failed = outbound && m.display_status === "failed"
    const color = failed
      ? "bg-red-50 text-red-900 border border-red-300"
      : outbound
        ? "bg-emerald-600 text-white"
        : "bg-white text-gray-900 border border-gray-200"

    const badge = outbound ? this.statusBadge(m, failed) : ""
    const errorRow = failed && m.error_message
      ? `<div class="mt-1 text-[11px] text-red-700 italic">Error: ${this.escape(m.error_message)}${m.error_code ? ` (${this.escape(m.error_code)})` : ""}</div>`
      : ""

    const timeClass = failed ? "text-red-400" : outbound ? "text-emerald-100" : "text-gray-400"

    return `
      <div class="flex ${align}">
        <div class="max-w-[75%] rounded-lg px-3 py-2 shadow-sm ${color}">
          ${this.mediaMarkup(m, outbound)}
          ${m.body ? `<div class="text-sm whitespace-pre-wrap break-words">${this.escape(m.body)}</div>` : ""}
          ${errorRow}
          <div class="mt-1 flex items-center justify-end gap-1.5 text-[10px] ${timeClass}">
            <span>${this.escape(m.formatted_time)}</span>
            ${badge}
          </div>
        </div>
      </div>`
  }

  statusBadge(m, failed) {
    const ds = m.display_status || "pending"
    if (failed) {
      return `<span class="inline-flex items-center gap-0.5 px-1.5 py-0.5 rounded text-[10px] font-medium bg-red-100 text-red-700">
        <svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M12 9v2m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
        Failed
      </span>`
    }
    if (ds === "delivered") {
      return `<span class="inline-flex items-center gap-0.5 text-emerald-100" title="Delivered">
        <svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7"/></svg>
        <svg class="h-3 w-3 -ml-1.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7"/></svg>
      </span>`
    }
    if (ds === "sent") {
      return `<span class="inline-flex items-center gap-0.5 text-emerald-100" title="Sent">
        <svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7"/></svg>
      </span>`
    }
    // pending / queued / sending
    return `<span class="inline-flex items-center gap-0.5 text-emerald-100/80" title="${this.escape(m.status || "queued")}">
      <svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z"/></svg>
    </span>`
  }

  mediaMarkup(m, outbound) {
    if (!m.media_url) return ""
    const ct = m.media_content_type || ""
    const linkColor = outbound ? "text-white underline" : "text-emerald-700 underline"

    if (ct.startsWith("image/")) {
      return `<a href="${m.media_url}" target="_blank" rel="noopener">
                <img src="${m.media_url}" class="mb-1 max-h-48 rounded-md" alt="attachment" />
              </a>`
    }
    if (ct.startsWith("audio/")) {
      return `<audio controls preload="metadata" src="${m.media_url}" class="mb-1 w-full h-8"></audio>`
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

    const mediaInput = t.requires_media_upload ? `
      <div class="mt-2">
        <label class="block text-xs font-medium text-gray-600 mb-1">Attach file <span class="text-red-500">*</span></label>
        <input type="file" data-template-file="true" data-required="true"
               accept="image/*,video/mp4,audio/*,.pdf,.doc,.docx,.xls,.xlsx,.pptx,.txt,.csv,.json,.xml,.zip"
               class="block w-full text-xs text-gray-700 file:mr-3 file:py-1.5 file:px-3 file:rounded-md file:border file:border-gray-300 file:bg-white file:text-gray-700 file:hover:bg-gray-50 file:text-xs file:font-medium" />
        <p class="mt-1 text-[11px] text-gray-500">This template needs a media attachment. Max 16MB.</p>
      </div>` : (t.has_media ? `
      <div class="mt-2 rounded-md bg-amber-50 border border-amber-200 px-3 py-2 text-[11px] text-amber-800">
        Twilio locked the media URL on this template at approval time, so per-send file uploads aren't possible.
        Re-approve the template with {{1}} as the media URL to send dynamic files.
      </div>` : "")

    return `
      <div class="border border-gray-200 rounded-md p-3 mb-3" data-template-sid="${this.escape(t.content_sid)}">
        <div class="flex items-start justify-between gap-3">
          <div class="min-w-0">
            <div class="text-sm font-semibold text-gray-900 truncate">
              ${this.escape(t.friendly_name || t.content_sid)}
              ${t.has_media ? `<span class="ml-1 inline-flex items-center px-1.5 py-0.5 rounded text-[10px] font-medium bg-emerald-100 text-emerald-700">MEDIA</span>` : ""}
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

  // Renders one variable row: a "From" dropdown that maps to a customer field,
  // alongside an editable text input. If the variable name looks like a known
  // customer attribute (e.g. {{name}}), we default the dropdown and pre-fill.
  variableRow(key) {
    const fields = this.customerFieldsValue || {}
    const autoField = this.customerFieldFor(key)
    const autoValue = autoField && fields[autoField] ? fields[autoField] : ""

    const option = (val, label, selected) =>
      `<option value="${this.escape(val)}"${selected ? " selected" : ""}>${this.escape(label)}</option>`

    const options = [
      option("", "Manual", !autoField),
      fields.name    !== undefined ? option("name", `Customer name (${fields.name || "—"})`, autoField === "name") : "",
      fields.phone   !== undefined ? option("phone", `Customer phone (${fields.phone || "—"})`, autoField === "phone") : "",
      fields.email   !== undefined ? option("email", `Customer email (${fields.email || "—"})`, autoField === "email") : "",
      fields.company !== undefined ? option("company", `Customer company (${fields.company || "—"})`, autoField === "company") : ""
    ].join("")

    return `
      <div class="mt-2">
        <label class="block text-xs font-medium text-gray-600 mb-1">Variable {{${this.escape(key)}}}</label>
        <div class="flex gap-2">
          <select data-action="change->whatsapp-us#variableSourceChanged"
                  data-var-source-for="${this.escape(key)}"
                  class="text-xs border-gray-300 rounded-md shadow-sm focus:ring-emerald-500 focus:border-emerald-500 w-40">
            ${options}
          </select>
          <input type="text" data-var-key="${this.escape(key)}"
                 value="${this.escape(autoValue)}"
                 class="flex-1 block w-full text-sm border-gray-300 rounded-md shadow-sm focus:ring-emerald-500 focus:border-emerald-500"
                 placeholder="Value for {{${this.escape(key)}}}" />
        </div>
      </div>`
  }

  // Maps a template variable name to a customer field if it's a known alias.
  customerFieldFor(key) {
    const k = String(key).toLowerCase()
    if (["name", "first_name", "firstname", "customer_name", "fullname", "full_name"].includes(k)) return "name"
    if (["phone", "mobile", "phone_number", "phonenumber"].includes(k)) return "phone"
    if (["email", "email_address"].includes(k)) return "email"
    if (["company", "organization", "org", "company_name"].includes(k)) return "company"
    return null
  }

  variableSourceChanged(event) {
    const sel = event.currentTarget
    const key = sel.dataset.varSourceFor
    const input = sel.closest(".mt-2")?.querySelector(`input[data-var-key="${CSS.escape(key)}"]`)
    if (!input) return
    const field = sel.value
    const fields = this.customerFieldsValue || {}
    if (field && fields[field] != null) {
      input.value = fields[field]
    }
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
    if (fileInput?.dataset.required === "true" && !file) {
      this.showTemplateError("Please choose a file before sending this template.")
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

  // ---- Voice notes --------------------------------------------------------

  // Browsers vary on what MediaRecorder accepts. We prefer formats Twilio
  // will accept directly; if none match we record whatever and rely on the
  // server-side transcoder (WhatsappAudioTranscoder) to convert to ogg/opus.
  preferredMimeType() {
    const candidates = [
      "audio/ogg;codecs=opus",
      "audio/mp4;codecs=mp4a.40.2",
      "audio/mp4",
      "audio/webm;codecs=opus",
      "audio/webm"
    ]
    if (typeof MediaRecorder === "undefined") return null
    return candidates.find((t) => MediaRecorder.isTypeSupported(t)) || ""
  }

  async startRecording() {
    if (!this.windowOpenValue) return
    if (this._recording) return
    this.hideError()

    if (!navigator.mediaDevices?.getUserMedia) {
      this.showError("Voice notes aren't supported in this browser.")
      return
    }

    try {
      this._audioStream = await navigator.mediaDevices.getUserMedia({ audio: true })
    } catch (e) {
      this.showError("Microphone permission denied.")
      return
    }

    const mimeType = this.preferredMimeType()
    try {
      this._recorder = mimeType ? new MediaRecorder(this._audioStream, { mimeType })
                                : new MediaRecorder(this._audioStream)
    } catch (e) {
      this.showError("Voice recording isn't supported in this browser.")
      this._stopStream()
      return
    }

    this._chunks = []
    this._recordingMime = this._recorder.mimeType || "audio/webm"
    this._recorder.addEventListener("dataavailable", (e) => { if (e.data.size > 0) this._chunks.push(e.data) })
    this._recorder.addEventListener("stop", () => this._handleRecorded())
    this._recorder.start()
    this._recording = true
    this._recordingStartedAt = Date.now()
    this.recordingBarTarget.classList.remove("hidden")
    this._tickTimer = setInterval(() => this._updateTimer(), 500)
    this._updateTimer()
    if (this.hasMicButtonTarget) this.micButtonTarget.disabled = true
  }

  stopRecording() {
    if (!this._recording || !this._recorder) return
    this._recorder.stop()
    this._recording = false
    clearInterval(this._tickTimer)
    this._tickTimer = null
    this.recordingBarTarget.classList.add("hidden")
    this._stopStream()
  }

  _stopStream() {
    if (this._audioStream) {
      this._audioStream.getTracks().forEach((t) => t.stop())
      this._audioStream = null
    }
  }

  _updateTimer() {
    const seconds = Math.floor((Date.now() - this._recordingStartedAt) / 1000)
    const m = Math.floor(seconds / 60)
    const s = String(seconds % 60).padStart(2, "0")
    if (this.hasRecordingTimerTarget) this.recordingTimerTarget.textContent = `${m}:${s}`
  }

  _handleRecorded() {
    const mime = this._recordingMime || "audio/webm"
    const blob = new Blob(this._chunks, { type: mime })
    this._voiceBlob = blob
    this._voiceMime = mime

    const url = URL.createObjectURL(blob)
    if (this._lastVoiceUrl) URL.revokeObjectURL(this._lastVoiceUrl)
    this._lastVoiceUrl = url
    this.voicePlayerTarget.src = url
    this.voicePreviewTarget.classList.remove("hidden")
    if (this.hasMicButtonTarget) this.micButtonTarget.disabled = !this.windowOpenValue
  }

  cancelVoice() {
    this._voiceBlob = null
    this._voiceMime = null
    this.voicePreviewTarget.classList.add("hidden")
    if (this._lastVoiceUrl) { URL.revokeObjectURL(this._lastVoiceUrl); this._lastVoiceUrl = null }
    this.voicePlayerTarget.removeAttribute("src")
  }

  async sendVoiceNote() {
    if (!this._voiceBlob || !this.windowOpenValue) return

    const ext = this._extensionFor(this._voiceMime)
    const file = new File([this._voiceBlob], `voice-note-${Date.now()}.${ext}`, { type: this._voiceMime })

    this.voiceSendButtonTarget.disabled = true
    this.hideError()
    try {
      const formData = new FormData()
      formData.append("file", file)
      const response = await fetch(`/customers/${this.customerIdValue}/whatsapp_us`, {
        method: "POST",
        headers: { Accept: "application/json", "X-CSRF-Token": this.csrfToken },
        body: formData
      })
      const data = await response.json()
      if (response.ok && data.success) {
        this.cancelVoice()
        this.loadMessages()
      } else {
        this.showError(data.error || "Failed to send voice note")
        if (response.status === 403) this.applyWindowState(false)
      }
    } catch (e) {
      this.showError("Network error — please try again")
    } finally {
      this.voiceSendButtonTarget.disabled = false
    }
  }

  _extensionFor(mime) {
    if (!mime) return "webm"
    if (mime.startsWith("audio/ogg")) return "ogg"
    if (mime.startsWith("audio/mp4")) return "m4a"
    if (mime.startsWith("audio/mpeg")) return "mp3"
    return "webm"
  }
}
