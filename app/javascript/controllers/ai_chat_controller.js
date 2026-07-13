import { Controller } from "@hotwired/stimulus"

// Conversational AI assistant scoped to one customer. The conversation is
// posted back to the server each turn (POST /customers/:id/chat_ai); the server
// answers with Claude and persists the turn. The saved thread is handed to us
// via the history value so it renders when the tab is (re)opened.
export default class extends Controller {
  static targets = ["messages", "input", "sendButton", "empty", "form"]
  static values = { customerId: Number, history: Array }

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

    const bubble = document.createElement("div")
    bubble.className = isUser
      ? "max-w-[80%] rounded-2xl rounded-br-sm bg-emerald-600 text-white px-4 py-2.5 text-sm whitespace-pre-wrap break-words shadow-sm"
      : "max-w-[80%] rounded-2xl rounded-bl-sm bg-white border border-gray-200 text-gray-800 px-4 py-2.5 text-sm whitespace-pre-wrap break-words shadow-sm"
    bubble.textContent = text

    row.appendChild(bubble)
    this.messagesTarget.appendChild(row)
    this.scrollToBottom()
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
