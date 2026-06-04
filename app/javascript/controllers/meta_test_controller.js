import { Controller } from "@hotwired/stimulus"

// Fires a synthetic Meta Conversions event via Settings::FeaturesController#test
// and renders the result inline. Bound from the Meta credentials partial.
export default class extends Controller {
  static targets = ["button", "result"]
  static values  = { url: String }

  async send() {
    this.setBusy(true)
    this.renderStatus("muted", "Sending…")

    try {
      const csrf = document.querySelector('meta[name="csrf-token"]')?.content
      const response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Accept": "application/json",
          "Content-Type": "application/json",
          ...(csrf ? { "X-CSRF-Token": csrf } : {})
        },
        credentials: "same-origin"
      })

      const data = await response.json().catch(() => ({}))

      if (data.success) {
        const received = data.body?.events_received
        const detail = received != null ? ` · events received: ${received}` : ""
        this.renderStatus("ok", `Accepted by Meta${detail}`)
      } else {
        const msg = data.error || data.body?.error?.message || `HTTP ${response.status}`
        this.renderStatus("err", `Failed: ${msg}`)
      }
    } catch (e) {
      this.renderStatus("err", `Network error: ${e.message}`)
    } finally {
      this.setBusy(false)
    }
  }

  setBusy(busy) {
    if (this.hasButtonTarget) this.buttonTarget.disabled = busy
  }

  renderStatus(tone, text) {
    if (!this.hasResultTarget) return
    const palette = {
      muted: { color: "var(--color-ink-soft)", glyph: "" },
      ok:    { color: "var(--brand-accent)",    glyph: "✓ " },
      err:   { color: "#a83a22",                glyph: "✗ " }
    }[tone] || { color: "var(--color-ink-soft)", glyph: "" }

    this.resultTarget.innerHTML = ""
    const span = document.createElement("span")
    span.style.color = palette.color
    span.textContent = palette.glyph + text
    this.resultTarget.appendChild(span)
  }
}
