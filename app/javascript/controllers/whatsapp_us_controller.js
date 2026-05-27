import { Controller } from "@hotwired/stimulus"

// Twilio-backed "WhatsApp US" chat. Lists messages from whatsapp_messages and
// sends freeform replies. The composer is disabled unless the customer's last
// inbound message is within the 24-hour reply window.
export default class extends Controller {
  static values = { customerId: Number, windowOpen: Boolean }
  static targets = ["messagesContainer", "messagesArea", "form", "input", "sendButton", "closedNotice", "error"]

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
    if (this.hasClosedNoticeTarget) this.closedNoticeTarget.classList.toggle("hidden", open)
    if (this.hasInputTarget) {
      this.inputTarget.placeholder = open ? "Type a message..." : "Reply window closed"
    }
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
          <div class="text-sm whitespace-pre-wrap break-words">${this.escape(m.body || "")}</div>
          <div class="mt-1 text-[10px] ${outbound ? "text-emerald-100" : "text-gray-400"} text-right">${meta}</div>
        </div>
      </div>`
  }

  async sendMessage(event) {
    event.preventDefault()
    if (!this.windowOpenValue) return

    const body = this.inputTarget.value.trim()
    if (!body) return

    this.sendButtonTarget.disabled = true
    this.hideError()

    try {
      const response = await fetch(`/customers/${this.customerIdValue}/whatsapp_us`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({ body })
      })
      const data = await response.json()

      if (response.ok && data.success) {
        this.inputTarget.value = ""
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
