import { Controller } from "@hotwired/stimulus"

// Proposal Generator chat. The rep describes/uploads a project; each turn is
// posted to /cost_estimates/chat (gpt-5.5) which reads any attached file. When
// the rep clicks "Generate proposal" we POST the conversation to
// /cost_estimates/generate_from_chat, which kicks off a background build, then
// poll /cost_estimates/:id/proposal_status until the PDF is ready.
export default class extends Controller {
  static targets = ["messages", "input", "sendButton", "empty", "form",
                    "file", "fileChip", "fileName", "generateBar", "generateButton", "result"]

  connect() {
    this.pending = false
    this.generating = false
    this.history = []
    this.selectedFile = null
  }

  // ---- chat ----

  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      this.send(event)
    }
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

    const text = this.inputTarget.value.trim()
    if (!text && !this.selectedFile) return

    const shownText = this.selectedFile ? `${text}${text ? "\n" : ""}📎 ${this.selectedFile.name}` : text
    this.inputTarget.value = ""
    this.autoGrow()
    this.appendMessage("user", shownText)
    // Client history holds only typed text; the server folds file text in.
    this.history.push({ role: "user", content: text || `(see attached ${this.selectedFile?.name})` })

    const fd = new FormData()
    fd.append("messages", JSON.stringify(this.history))
    if (this.selectedFile) fd.append("file", this.selectedFile)
    const hadFile = this.selectedFile
    this.clearFile()

    this.setPending(true)
    const typing = this.appendTyping()

    try {
      const res = await fetch("/cost_estimates/chat", {
        method: "POST",
        credentials: "same-origin",
        headers: { "Accept": "application/json", "X-CSRF-Token": this._csrf() },
        body: fd,
      })
      const result = await res.json().catch(() => ({}))
      typing.remove()

      if (res.ok && result.success) {
        this.appendMessage("assistant", result.reply)
        this.history.push({ role: "assistant", content: result.reply })
        this.generateBarTarget.classList.remove("hidden")
      } else {
        this.appendError(result.error || "Something went wrong. Please try again.")
        this.history.pop()
      }
    } catch (e) {
      typing.remove()
      this.appendError("Network error. Please try again.")
      this.history.pop()
      if (hadFile) console.error("proposal chat error", e)
    } finally {
      this.setPending(false)
      this.inputTarget.focus()
    }
  }

  // ---- generate ----

  async generate() {
    if (this.generating) return
    if (!this.history.some((m) => m.role === "user")) {
      this._result("Tell me about the project first, then generate.", "warn")
      return
    }
    this.generating = true
    this.generateButtonTarget.disabled = true
    this._result("Building the proposal… this can take up to a minute.", "info")

    try {
      const res = await fetch("/cost_estimates/generate_from_chat", {
        method: "POST",
        credentials: "same-origin",
        headers: { "Content-Type": "application/json", "Accept": "application/json", "X-CSRF-Token": this._csrf() },
        body: JSON.stringify({ messages: this.history }),
      })
      const data = await res.json().catch(() => ({}))
      if (!res.ok || !data.success) {
        this._result(data.error || "Couldn't start the build. Please try again.", "warn")
        this._resetGenerate()
        return
      }
      this._poll(data.status_url)
    } catch (e) {
      console.error("generate error", e)
      this._result("Network error starting the build. Please try again.", "warn")
      this._resetGenerate()
    }
  }

  _poll(statusUrl) {
    let tries = 0
    const tick = async () => {
      tries++
      try {
        const res = await fetch(statusUrl, { credentials: "same-origin", headers: { "Accept": "application/json" } })
        const d = await res.json().catch(() => ({}))
        if (d.ready && d.download_url) {
          this._done(d)
          return
        }
        if (d.failed) {
          this._result("The proposal build failed. Please try again.", "warn")
          this._resetGenerate()
          return
        }
      } catch (e) {
        // keep polling through transient errors
      }
      if (tries > 120) { // ~6 min safety cap (quality mockups can be slow)
        this._result("This is taking longer than expected. Check 'Recent proposals' shortly.", "warn")
        this._resetGenerate()
        return
      }
      setTimeout(tick, 3000)
    }
    setTimeout(tick, 3000)
  }

  _done(d) {
    const name = d.project_name || "Proposal"
    this.resultTarget.innerHTML = ""
    const link = document.createElement("a")
    link.href = d.download_url
    link.target = "_blank"
    link.rel = "noopener"
    link.className = "font-semibold underline"
    link.textContent = `Download ${name} (${d.total_hours}h · ${d.total_cost})`
    const span = document.createElement("span")
    span.textContent = "Proposal ready. "
    this.resultTarget.append(span, link)
    this.resultTarget.dataset.state = "success"
    this.generateButtonTarget.disabled = false
    this.generating = false
    window.open(d.download_url, "_blank", "noopener")
    this.appendMessage("assistant", `Your proposal for ${name} is ready. It's ${d.total_hours} hours at a total of ${d.total_cost}. The PDF just opened in a new tab, and it's under Recent proposals below.`)
  }

  _resetGenerate() {
    this.generateButtonTarget.disabled = false
    this.generating = false
  }

  // ---- rendering ----

  appendMessage(role, text) {
    if (this.hasEmptyTarget) this.emptyTarget.classList.add("hidden")
    const isUser = role === "user"
    const row = document.createElement("div")
    row.className = `flex ${isUser ? "justify-end" : "justify-start"}`
    const bubble = document.createElement("div")
    bubble.className = isUser
      ? "max-w-[80%] rounded-2xl rounded-br-sm bg-emerald-600 text-white px-4 py-2.5 text-sm whitespace-pre-wrap break-words shadow-sm"
      : "max-w-[85%] rounded-2xl rounded-bl-sm bg-white border border-gray-200 text-gray-800 px-4 py-2.5 text-sm whitespace-pre-wrap break-words shadow-sm"
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

  // ---- helpers ----

  _result(msg, state = "info") {
    this.resultTarget.textContent = msg
    this.resultTarget.dataset.state = state
  }

  _csrf() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }

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
