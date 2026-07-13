import { Controller } from "@hotwired/stimulus"

// Conversational AI assistant scoped to one customer. The conversation is
// posted back to the server each turn (POST /customers/:id/chat_ai); the server
// answers with Claude and persists the turn. The saved thread is handed to us
// via the history value so it renders when the tab is (re)opened.
export default class extends Controller {
  static targets = ["messages", "input", "sendButton", "empty", "form"]
  static values = {
    customerId: Number,
    customerName: String,
    canEmail: Boolean,
    canWhatsapp: Boolean,
    history: Array
  }

  connect() {
    this.pending = false
    this.history = this.hasHistoryValue ? this.historyValue.slice() : []
    this.renderHistory()
  }

  renderHistory() {
    for (const message of this.history) {
      if (message && message.role && message.content) {
        this.appendMessage(message.role, message.content)
      }
    }
  }

  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.send(event)
    }
  }

  async send(event) {
    if (event) event.preventDefault()
    if (this.pending) return

    const text = this.inputTarget.value.trim()
    if (!text) return

    this.inputTarget.value = ""
    this.autoGrow()
    this.appendMessage("user", text)
    this.history.push({ role: "user", content: text })

    this.setPending(true)
    const typing = this.appendTyping()

    try {
      const response = await fetch(`/customers/${this.customerIdValue}/chat_ai`, {
        method: "POST",
        credentials: "same-origin",
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "X-CSRF-Token": document.querySelector('[name="csrf-token"]')?.content || ""
        },
        body: JSON.stringify({ messages: this.history })
      })

      const result = await response.json().catch(() => ({}))
      typing.remove()

      if (response.ok && result.success) {
        this.appendMessage("assistant", result.reply)
        this.history.push({ role: "assistant", content: result.reply })
      } else {
        this.appendError(result.error || "Something went wrong. Please try again.")
        // Drop the unanswered user turn so a retry doesn't duplicate it.
        this.history.pop()
      }
    } catch (error) {
      console.error("AI chat error:", error)
      typing.remove()
      this.appendError("Network error. Please check your connection and try again.")
      this.history.pop()
    } finally {
      this.setPending(false)
      this.inputTarget.focus()
    }
  }

  ask(event) {
    // Quick-prompt chips: fill the input with a suggested question and send it.
    const prompt = event.currentTarget.dataset.prompt
    if (!prompt) return
    this.inputTarget.value = prompt
    this.send(event)
  }

  // --- rendering -----------------------------------------------------------

  appendMessage(role, text) {
    if (this.hasEmptyTarget) this.emptyTarget.classList.add("hidden")

    const isUser = role === "user"
    const row = document.createElement("div")
    row.className = `flex ${isUser ? "justify-end" : "justify-start"}`

    if (isUser) {
      const bubble = document.createElement("div")
      bubble.className = "max-w-[80%] rounded-2xl rounded-br-sm bg-emerald-600 text-white px-4 py-2.5 text-sm whitespace-pre-wrap break-words shadow-sm"
      bubble.textContent = text
      row.appendChild(bubble)
    } else {
      const col = document.createElement("div")
      col.className = "max-w-[80%] flex flex-col items-start gap-1.5"

      const bubble = document.createElement("div")
      bubble.className = "rounded-2xl rounded-bl-sm bg-white border border-gray-200 text-gray-800 px-4 py-2.5 text-sm whitespace-pre-wrap break-words shadow-sm"
      bubble.textContent = text
      col.appendChild(bubble)

      const actions = this.buildSendActions(text)
      if (actions) col.appendChild(actions)
      row.appendChild(col)
    }

    this.messagesTarget.appendChild(row)
    this.scrollToBottom()
  }

  // --- sending drafts ------------------------------------------------------

  // Buttons under each assistant reply to send it to the customer. Only the
  // channels the customer actually has are offered. Nothing sends without an
  // explicit click and a confirm.
  buildSendActions(text) {
    if (!this.canWhatsappValue && !this.canEmailValue) return null

    const bar = document.createElement("div")
    bar.className = "flex flex-wrap items-center gap-2 pl-1"

    if (this.canWhatsappValue) {
      const btn = this.actionButton("Send on WhatsApp")
      btn.addEventListener("click", () => this.dispatchSend("whatsapp", text, bar))
      bar.appendChild(btn)
    }
    if (this.canEmailValue) {
      const btn = this.actionButton("Send as email")
      btn.addEventListener("click", () => this.dispatchSend("email", text, bar))
      bar.appendChild(btn)
    }
    return bar
  }

  actionButton(label) {
    const btn = document.createElement("button")
    btn.type = "button"
    btn.className = "inline-flex items-center gap-1 px-2.5 py-1 rounded-md border border-gray-200 bg-white text-[11px] font-medium text-gray-600 hover:bg-gray-50 hover:border-gray-300 disabled:opacity-50 disabled:cursor-not-allowed"
    btn.textContent = label
    return btn
  }

  async dispatchSend(channel, text, bar) {
    const name = this.hasCustomerNameValue ? this.customerNameValue : "this customer"
    const isWhatsapp = channel === "whatsapp"
    if (!confirm(`Send this ${isWhatsapp ? "WhatsApp message" : "email"} to ${name}?`)) return

    const buttons = bar.querySelectorAll("button")
    buttons.forEach((b) => (b.disabled = true))

    try {
      const result = isWhatsapp ? await this.postWhatsapp(text) : await this.postEmail(text)
      if (result.ok) {
        this.markSent(bar, isWhatsapp ? "Sent on WhatsApp" : "Sent as email")
      } else {
        this.showActionError(bar, result.error || "Could not send. Please try again.")
        buttons.forEach((b) => (b.disabled = false))
      }
    } catch (error) {
      console.error("AI chat send error:", error)
      this.showActionError(bar, "Network error. Please try again.")
      buttons.forEach((b) => (b.disabled = false))
    }
  }

  async postWhatsapp(text) {
    const response = await fetch(`/customers/${this.customerIdValue}/messages`, {
      method: "POST",
      credentials: "same-origin",
      headers: this.jsonHeaders(),
      body: JSON.stringify({ message: { content: text } })
    })
    const data = await response.json().catch(() => ({}))
    return { ok: response.ok, error: data.error || data.message }
  }

  async postEmail(text) {
    const { subject, body } = this.splitEmail(text)
    const response = await fetch(`/customers/${this.customerIdValue}/emails`, {
      method: "POST",
      credentials: "same-origin",
      headers: this.jsonHeaders(),
      body: JSON.stringify({ subject: subject, body_html: this.toHtml(body) })
    })
    const data = await response.json().catch(() => ({}))
    return { ok: response.ok, error: data.error || data.message }
  }

  // Pull a leading "Subject: ..." line out of an email draft; fall back to a
  // neutral subject if the model didn't include one.
  splitEmail(text) {
    const match = text.match(/^\s*subject\s*:\s*(.+)$/im)
    if (match) {
      const subject = match[1].trim()
      const body = text.replace(/^\s*subject\s*:.*(?:\r?\n)+/im, "").trim()
      return { subject, body }
    }
    return { subject: "Following up", body: text.trim() }
  }

  markSent(bar, label) {
    bar.innerHTML = ""
    const note = document.createElement("span")
    note.className = "inline-flex items-center gap-1 text-xs font-medium text-emerald-600 pl-1"
    note.textContent = `${label} ✓`
    bar.appendChild(note)
  }

  showActionError(bar, message) {
    let err = bar.querySelector("[data-send-error]")
    if (!err) {
      err = document.createElement("span")
      err.setAttribute("data-send-error", "1")
      err.className = "text-xs text-red-600 pl-1 w-full"
      bar.appendChild(err)
    }
    err.textContent = message
  }

  jsonHeaders() {
    return {
      "Content-Type": "application/json",
      "Accept": "application/json",
      "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
    }
  }

  toHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML.replace(/\n/g, "<br>")
  }

  appendTyping() {
    const row = document.createElement("div")
    row.className = "flex justify-start"
    row.innerHTML = `
      <div class="rounded-2xl rounded-bl-sm bg-white border border-gray-200 px-4 py-3 shadow-sm">
        <div class="flex items-center gap-1">
          <span class="h-2 w-2 rounded-full bg-gray-400 animate-bounce" style="animation-delay:0ms"></span>
          <span class="h-2 w-2 rounded-full bg-gray-400 animate-bounce" style="animation-delay:150ms"></span>
          <span class="h-2 w-2 rounded-full bg-gray-400 animate-bounce" style="animation-delay:300ms"></span>
        </div>
      </div>`
    this.messagesTarget.appendChild(row)
    this.scrollToBottom()
    return row
  }

  appendError(message) {
    const row = document.createElement("div")
    row.className = "flex justify-start"
    row.innerHTML = `<div class="max-w-[80%] rounded-lg bg-red-50 border border-red-200 text-red-700 px-4 py-2.5 text-sm"></div>`
    row.querySelector("div").textContent = message
    this.messagesTarget.appendChild(row)
    this.scrollToBottom()
  }

  // --- helpers -------------------------------------------------------------

  setPending(pending) {
    this.pending = pending
    if (this.hasSendButtonTarget) this.sendButtonTarget.disabled = pending
    this.inputTarget.disabled = pending
  }

  autoGrow() {
    this.inputTarget.style.height = "auto"
    this.inputTarget.style.height = `${Math.min(this.inputTarget.scrollHeight, 160)}px`
  }

  scrollToBottom() {
    requestAnimationFrame(() => {
      this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    })
  }
}
