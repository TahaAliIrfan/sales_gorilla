// app/javascript/controllers/relay/composer_controller.js
// Drives the lead-workspace composer: channel tabs (WhatsApp / Email / Note),
// textarea autosize, and ⌘↵ / Ctrl+↵ to submit the active channel's form.
// Each tab is a real <form> that posts to its existing endpoint and responds
// with a turbo_stream that appends the new event to the conversation canvas.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel", "input"]

  connect() {
    this.select(this.activeTab() || "whatsapp")
  }

  activeTab() {
    const current = this.tabTargets.find((t) => t.classList.contains("is-active"))
    return current ? current.dataset.channel : null
  }

  switch(event) {
    this.select(event.currentTarget.dataset.channel)
  }

  select(channel) {
    this.tabTargets.forEach((t) =>
      t.classList.toggle("is-active", t.dataset.channel === channel)
    )
    this.panelTargets.forEach((p) =>
      p.hidden = p.dataset.channel !== channel
    )
    const input = this.inputTargets.find(
      (i) => i.closest("[data-channel]")?.dataset.channel === channel
    )
    if (input) input.focus()
  }

  // Grow the textarea up to a sane cap as the user types.
  autosize(event) {
    const el = event.currentTarget
    el.style.height = "auto"
    el.style.height = Math.min(el.scrollHeight, 180) + "px"
  }

  // ⌘↵ / Ctrl+↵ submits the form the textarea belongs to.
  submitOnCmdEnter(event) {
    if (event.key === "Enter" && (event.metaKey || event.ctrlKey)) {
      event.preventDefault()
      event.currentTarget.closest("form")?.requestSubmit()
    }
  }

  // After a successful turbo_stream append, clear the just-sent form and
  // scroll the canvas to the newest event.
  reset(event) {
    const form = event.target
    if (form && typeof form.reset === "function") form.reset()
    this.inputTargets.forEach((i) => { i.style.height = "auto" })
    const tail = document.getElementById("conversation_tail")
    if (tail) tail.scrollIntoView({ behavior: "smooth", block: "end" })
  }
}
