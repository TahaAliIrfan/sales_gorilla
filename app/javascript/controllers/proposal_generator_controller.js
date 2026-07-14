import { Controller } from "@hotwired/stimulus"

// Proposal Generator with ChatGPT-style multiple persisted chats + one-click
// "import a customer's whole history" as context. All state lives server-side
// (proposal_chats); this controller loads/switches chats, posts turns, imports
// customers, and kicks off the proposal build (polling proposal_status).
export default class extends Controller {
  static targets = ["chatList", "messages", "empty", "input", "sendButton", "form",
                    "file", "fileChip", "fileName", "generateBar", "generateButton", "result",
                    "customerChip", "importPanel", "customerSearch", "customerResults"]

  connect() {
    this.currentId = null
    this.pending = false
    this.generating = false
    this.selectedFile = null
    this.loadChats(true)
  }

  // ---- chat list ----

  async loadChats(openFirst = false) {
    const data = await this._get("/proposal_chats")
    this.renderChatList(data.chats || [])
    if (openFirst) {
      if (data.chats && data.chats.length) this.openChat(data.chats[0].id)
      else this.newChat()
    }
  }

  renderChatList(chats) {
    this.chatListTarget.innerHTML = ""
    chats.forEach((c) => this.chatListTarget.appendChild(this._chatRow(c)))
  }

  _chatRow(c) {
    const row = document.createElement("div")
    row.dataset.chatId = c.id
    const active = c.id === this.currentId
    row.className = `group flex items-center gap-1 rounded-lg px-2.5 py-2 cursor-pointer ${active ? "bg-emerald-50" : "hover:bg-gray-50"}`
    const title = document.createElement("div")
    title.className = "flex-1 min-w-0"
    title.innerHTML = `<div class="text-sm text-gray-800 truncate">${this._esc(c.title)}</div><div class="text-[11px] text-gray-400">${this._esc(c.updated_at || "")}</div>`
    title.addEventListener("click", () => this.openChat(c.id))
    const del = document.createElement("button")
    del.className = "opacity-0 group-hover:opacity-100 h-6 w-6 grid place-items-center rounded text-gray-400 hover:text-red-600 hover:bg-red-50 shrink-0"
    del.innerHTML = `<svg class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16"/></svg>`
    del.addEventListener("click", (e) => { e.stopPropagation(); this.deleteChat(c.id) })
    row.append(title, del)
    return row
  }

  async newChat() {
    const chat = await this._post("/proposal_chats", {})
    if (!chat || !chat.id) return
    this.currentId = chat.id
    await this.loadChats()
    this._clearConversation()
  }

  async openChat(id) {
    this.currentId = id
    this._highlightActive()
    const data = await this._get(`/proposal_chats/${id}`)
    this._clearConversation()
    this._setCustomerChip(data.customer)
    ;(data.messages || []).forEach((m) => this.renderMessage(m))
    if (data.messages && data.messages.length) this.generateBarTarget.classList.remove("hidden")
  }

  async deleteChat(id) {
    if (!confirm("Delete this chat?")) return
    await this._delete(`/proposal_chats/${id}`)
    if (id === this.currentId) { this.currentId = null; this._clearConversation() }
    await this.loadChats(id === this.currentId)
    if (!this.currentId) this.loadChats(true)
  }

  // ---- messaging ----

  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) { event.preventDefault(); this.send(event) }
  }

  fileSelected() {
    const f = this.fileTarget.files[0]
    if (!f) return
    this.selectedFile = f
    this.fileNameTarget.textContent = f.name
    this.fileChipTarget.classList.remove("hidden")
  }

  clearFile() {
    this.selectedFile = null
    this.fileTarget.value = ""
    this.fileChipTarget.classList.add("hidden")
  }

  async send(event) {
    if (event) event.preventDefault()
    if (this.pending) return
    if (!this.currentId) await this.newChat()

    const text = this.inputTarget.value.trim()
    if (!text && !this.selectedFile) return

    const shown = this.selectedFile ? `${text}${text ? "\n" : ""}📎 ${this.selectedFile.name}` : text
    this.inputTarget.value = ""
    this.autoGrow()
    this.renderMessage({ role: "user", content: shown })

    const fd = new FormData()
    fd.append("content", text)
    if (this.selectedFile) fd.append("file", this.selectedFile)
    this.clearFile()

    this.setPending(true)
    const typing = this._appendTyping()
    try {
      const res = await fetch(`/proposal_chats/${this.currentId}/message`, {
        method: "POST", credentials: "same-origin",
        headers: { "Accept": "application/json", "X-CSRF-Token": this._csrf() }, body: fd,
      })
      const data = await res.json().catch(() => ({}))
      typing.remove()
      if (res.ok && data.success) {
        this.renderMessage({ role: "assistant", content: data.reply })
        this.generateBarTarget.classList.remove("hidden")
        this._touchChat(data.title)
      } else {
        this._appendError(data.error || "Something went wrong. Please try again.")
      }
    } catch (e) {
      typing.remove()
      this._appendError("Network error. Please try again.")
    } finally {
      this.setPending(false)
      this.inputTarget.focus()
    }
  }

  // ---- customer import ----

  toggleImport() {
    this.importPanelTarget.classList.toggle("hidden")
    if (!this.importPanelTarget.classList.contains("hidden")) this.customerSearchTarget.focus()
  }

  async searchCustomers() {
    const q = this.customerSearchTarget.value.trim()
    if (q.length < 2) { this.customerResultsTarget.innerHTML = ""; return }
    const data = await this._get(`/proposal_chats/customer_search?q=${encodeURIComponent(q)}`)
    this.customerResultsTarget.innerHTML = ""
    ;(data.customers || []).forEach((c) => {
      const b = document.createElement("button")
      b.type = "button"
      b.className = "w-full text-left px-2.5 py-1.5 rounded hover:bg-emerald-50 text-sm"
      b.innerHTML = `<span class="text-gray-800">${this._esc(c.name || "(no name)")}</span>${c.company ? `<span class="text-gray-400"> · ${this._esc(c.company)}</span>` : ""}`
      b.addEventListener("click", () => this.importCustomer(c.id))
      this.customerResultsTarget.appendChild(b)
    })
    if (!(data.customers || []).length) this.customerResultsTarget.innerHTML = `<div class="px-2.5 py-2 text-xs text-gray-400">No matches</div>`
  }

  async importCustomer(customerId) {
    if (!this.currentId) await this.newChat()
    this.customerResultsTarget.innerHTML = `<div class="px-2.5 py-2 text-xs text-gray-500">Importing…</div>`
    const data = await this._post(`/proposal_chats/${this.currentId}/import_customer`, { customer_id: customerId })
    this.importPanelTarget.classList.add("hidden")
    this.customerSearchTarget.value = ""
    this.customerResultsTarget.innerHTML = ""
    if (data && data.success) {
      this._setCustomerChip({ label: data.label })
      this.renderMessage({ role: "context", content: data.label })
      this.generateBarTarget.classList.remove("hidden")
      this._touchChat(data.title)
    }
  }

  // ---- generate ----

  async generate() {
    if (this.generating || !this.currentId) return
    this.generating = true
    this.generateButtonTarget.disabled = true
    this._result("Building the proposal… this can take a couple of minutes.", "info")
    try {
      const data = await this._post(`/proposal_chats/${this.currentId}/generate`, {})
      if (!data || !data.success) { this._result((data && data.error) || "Couldn't start the build.", "warn"); this._resetGenerate(); return }
      this._poll(data.status_url)
    } catch (e) {
      this._result("Network error starting the build.", "warn"); this._resetGenerate()
    }
  }

  _poll(statusUrl) {
    let tries = 0
    const tick = async () => {
      tries++
      try {
        const d = await this._get(statusUrl)
        if (d.ready && d.download_url) { this._done(d); return }
        if (d.failed) { this._result("The proposal build failed. Please try again.", "warn"); this._resetGenerate(); return }
      } catch (e) { /* keep polling */ }
      if (tries > 120) { this._result("Taking longer than expected. Check 'Recent proposals' shortly.", "warn"); this._resetGenerate(); return }
      setTimeout(tick, 3000)
    }
    setTimeout(tick, 3000)
  }

  _done(d) {
    const name = d.project_name || "Proposal"
    this.resultTarget.innerHTML = ""
    const span = document.createElement("span"); span.textContent = "Proposal ready. "
    const link = document.createElement("a")
    link.href = d.download_url; link.target = "_blank"; link.rel = "noopener"
    link.className = "font-semibold underline"
    link.textContent = `Download ${name} (${d.total_hours}h · ${d.total_cost})`
    this.resultTarget.append(span, link)
    this.resultTarget.dataset.state = "success"
    this._resetGenerate()
    window.open(d.download_url, "_blank", "noopener")
  }

  _resetGenerate() { this.generateButtonTarget.disabled = false; this.generating = false }

  // ---- rendering ----

  renderMessage(m) {
    if (this.hasEmptyTarget) this.emptyTarget.classList.add("hidden")
    if (m.role === "context") { this.messagesTarget.appendChild(this._contextChip(m.content)); this._scroll(); return }
    const isUser = m.role === "user"
    const row = document.createElement("div")
    row.className = `flex ${isUser ? "justify-end" : "justify-start"}`
    const bubble = document.createElement("div")
    bubble.className = isUser
      ? "max-w-[80%] rounded-2xl rounded-br-sm bg-emerald-600 text-white px-4 py-2.5 text-sm whitespace-pre-wrap break-words shadow-sm"
      : "max-w-[85%] rounded-2xl rounded-bl-sm bg-white border border-gray-200 text-gray-800 px-4 py-2.5 text-sm whitespace-pre-wrap break-words shadow-sm"
    bubble.textContent = m.content
    row.appendChild(bubble)
    this.messagesTarget.appendChild(row)
    this._scroll()
  }

  _contextChip(label) {
    const row = document.createElement("div")
    row.className = "flex justify-center"
    row.innerHTML = `<div class="inline-flex items-center gap-1.5 text-xs bg-emerald-50 border border-emerald-200 text-emerald-800 rounded-full px-3 py-1">
      <svg class="h-3.5 w-3.5" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="2"><path stroke-linecap="round" stroke-linejoin="round" d="M5 8h14M5 8a2 2 0 110-4h14a2 2 0 110 4M5 8v10a2 2 0 002 2h10a2 2 0 002-2V8"/></svg>
      Imported: ${this._esc(label)}</div>`
    return row
  }

  _setCustomerChip(customer) {
    if (customer && customer.label) {
      this.customerChipTarget.textContent = `Context: ${customer.label}`
    } else {
      this.customerChipTarget.textContent = ""
    }
  }

  _appendTyping() {
    const row = document.createElement("div")
    row.className = "flex justify-start"
    row.innerHTML = `<div class="rounded-2xl rounded-bl-sm bg-white border border-gray-200 px-4 py-3 shadow-sm"><div class="flex items-center gap-1">
      <span class="h-2 w-2 rounded-full bg-gray-400 animate-bounce" style="animation-delay:0ms"></span>
      <span class="h-2 w-2 rounded-full bg-gray-400 animate-bounce" style="animation-delay:150ms"></span>
      <span class="h-2 w-2 rounded-full bg-gray-400 animate-bounce" style="animation-delay:300ms"></span></div></div>`
    this.messagesTarget.appendChild(row); this._scroll(); return row
  }

  _appendError(message) {
    const row = document.createElement("div")
    row.className = "flex justify-start"
    row.innerHTML = `<div class="max-w-[80%] rounded-lg bg-red-50 border border-red-200 text-red-700 px-4 py-2.5 text-sm"></div>`
    row.querySelector("div").textContent = message
    this.messagesTarget.appendChild(row); this._scroll()
  }

  _clearConversation() {
    this.messagesTarget.querySelectorAll(":scope > div:not([data-proposal-generator-target='empty'])").forEach((el) => el.remove())
    if (this.hasEmptyTarget) this.emptyTarget.classList.remove("hidden")
    this.generateBarTarget.classList.add("hidden")
    this._result("Ready when you are, generate the full proposal PDF.", "info")
    this._setCustomerChip(null)
  }

  _highlightActive() {
    this.chatListTarget.querySelectorAll("[data-chat-id]").forEach((el) => {
      const on = Number(el.dataset.chatId) === Number(this.currentId)
      el.classList.toggle("bg-emerald-50", on)
      el.classList.toggle("hover:bg-gray-50", !on)
    })
  }

  _touchChat(title) {
    // Reflect a new/updated title in the sidebar without a full reload.
    const row = this.chatListTarget.querySelector(`[data-chat-id='${this.currentId}'] .text-sm`)
    if (row && title) row.textContent = title
    else this.loadChats()
  }

  // ---- helpers ----

  setPending(p) { this.pending = p; if (this.hasSendButtonTarget) this.sendButtonTarget.disabled = p; this.inputTarget.disabled = p }
  autoGrow() { this.inputTarget.style.height = "auto"; this.inputTarget.style.height = `${Math.min(this.inputTarget.scrollHeight, 160)}px` }
  _scroll() { requestAnimationFrame(() => { this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight }) }
  _result(msg, state = "info") { this.resultTarget.textContent = msg; this.resultTarget.dataset.state = state }
  _csrf() { return document.querySelector('meta[name="csrf-token"]')?.content || "" }
  _esc(s) { const d = document.createElement("div"); d.textContent = s == null ? "" : String(s); return d.innerHTML }

  async _get(url) {
    const res = await fetch(url, { credentials: "same-origin", headers: { "Accept": "application/json" } })
    return res.json().catch(() => ({}))
  }
  async _post(url, body) {
    const res = await fetch(url, { method: "POST", credentials: "same-origin",
      headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": this._csrf() },
      body: JSON.stringify(body) })
    return res.json().catch(() => ({}))
  }
  async _delete(url) {
    await fetch(url, { method: "DELETE", credentials: "same-origin", headers: { "Accept": "application/json", "X-CSRF-Token": this._csrf() } })
  }
}
