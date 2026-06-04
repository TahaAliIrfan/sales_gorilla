import { Controller } from "@hotwired/stimulus"

// Diagnostics for Settings > Features > Meta Conversions API. Two actions:
//   verify — preflight GET to graph.facebook.com/<pixel_id> to confirm the
//            access token actually owns this pixel.
//   send   — POST a synthetic Lead event via Settings::FeaturesController#test.
// Both render a rich result card with fbtrace_id, Meta messages, and (for
// send) the exact JSON payload that hit Meta's edge.
export default class extends Controller {
  static targets = ["button", "verifyButton", "result"]
  static values  = {
    url:               String,
    verifyUrl:         String,
    eventsManagerUrl:  String
  }

  // ── Public actions ─────────────────────────────────────────────────────
  async send() {
    this.setBusy(true)
    this.show()
    this.render(`<p class="text-ink-soft">Sending…</p>`)

    try {
      const data = await this.post(this.urlValue)
      this.render(this.formatSendResult(data))
    } catch (e) {
      this.render(this.formatError(`Network error: ${e.message}`))
    } finally {
      this.setBusy(false)
    }
  }

  async verify() {
    this.setVerifyBusy(true)
    this.show()
    this.render(`<p class="text-ink-soft">Verifying pixel…</p>`)

    try {
      const data = await this.post(this.verifyUrlValue)
      this.render(this.formatVerifyResult(data))
    } catch (e) {
      this.render(this.formatError(`Network error: ${e.message}`))
    } finally {
      this.setVerifyBusy(false)
    }
  }

  // ── Result formatters ──────────────────────────────────────────────────
  formatSendResult(data) {
    if (data.success) {
      const received = data.events_received ?? "unknown"
      const messages = Array.isArray(data.messages) && data.messages.length
        ? `<div class="mt-2 text-[11px]" style="color:#b07300">Warnings: ${this.esc(data.messages.join(" · "))}</div>`
        : ""

      const trace = data.fbtrace_id
        ? `<dt class="text-ink-soft/70">fbtrace_id</dt><dd class="text-ink break-all">${this.esc(data.fbtrace_id)}</dd>`
        : ""

      const link = this.eventsManagerUrlValue
        ? `<a href="${this.eventsManagerUrlValue}" target="_blank" rel="noopener" class="underline hover:text-ink">Open Events Manager →</a>`
        : ""

      return `
        <div class="space-y-2">
          <p style="color: var(--brand-accent); font-weight: 600;">✓ Accepted by Meta</p>
          <dl class="mono grid grid-cols-[max-content_1fr] gap-x-3 gap-y-1 text-[11px]">
            <dt class="text-ink-soft/70">events_received</dt><dd class="text-ink">${this.esc(received)}</dd>
            ${trace}
          </dl>
          ${messages}
          <div class="mt-1 text-[11px] text-ink-soft">${link}</div>
          ${this.payloadBlock(data.payload)}
        </div>
      `
    }

    const reason = data.error || data.body?.error?.message || "Unknown error"
    const trace = data.fbtrace_id || data.body?.error?.fbtrace_id
    const traceLine = trace
      ? `<dt class="text-ink-soft/70">fbtrace_id</dt><dd class="text-ink break-all">${this.esc(trace)}</dd>`
      : ""

    return `
      <div class="space-y-2">
        <p style="color: #a83a22; font-weight: 600;">✗ Rejected by Meta</p>
        <p class="text-sm text-ink">${this.esc(reason)}</p>
        ${traceLine ? `<dl class="mono grid grid-cols-[max-content_1fr] gap-x-3 gap-y-1 text-[11px]">${traceLine}</dl>` : ""}
        ${this.payloadBlock(data.payload)}
      </div>
    `
  }

  formatVerifyResult(data) {
    if (data.ok) {
      return `
        <div class="space-y-2">
          <p style="color: var(--brand-accent); font-weight: 600;">✓ Pixel verified</p>
          <dl class="mono grid grid-cols-[max-content_1fr] gap-x-3 gap-y-1 text-[11px]">
            <dt class="text-ink-soft/70">Pixel name</dt><dd class="text-ink">${this.esc(data.name || "(unnamed)")}</dd>
            <dt class="text-ink-soft/70">Pixel ID</dt><dd class="text-ink">${this.esc(data.id || "")}</dd>
            ${data.creation_time ? `<dt class="text-ink-soft/70">Created</dt><dd class="text-ink">${this.esc(data.creation_time)}</dd>` : ""}
          </dl>
          <p class="text-[11px] text-ink-soft">Your access token has read access to this pixel. Events will be routed here.</p>
        </div>
      `
    }

    // Permission-only error: token works for sending events but lacks
    // ads_management for reading pixel metadata. Render as informational
    // (yellow), not a failure (red).
    if (data.permission_only_error) {
      const trace = data.fbtrace_id
      return `
        <div class="space-y-2">
          <p style="color: #b07300; font-weight: 600;">⚠ Pixel metadata is not readable</p>
          <p class="text-sm text-ink">
            Your access token lacks <code>ads_management</code> permission, so we can't fetch
            the pixel's name. <b>This is not a problem for sending events</b> — the CAPI events
            endpoint uses a separate, looser permission check.
          </p>
          <p class="text-[11px] text-ink-soft">
            If "Send test event" returns <code>events_received: 1</code>, your CAPI setup is working correctly.
            To enable the metadata check too, add <code>ads_management</code> to your system user in Meta Business Manager.
          </p>
          ${trace ? `<p class="mono text-[11px] text-ink-soft">fbtrace_id: ${this.esc(trace)}</p>` : ""}
        </div>
      `
    }

    const reason = data.error || "Unknown error"
    const trace = data.fbtrace_id
    return `
      <div class="space-y-2">
        <p style="color: #a83a22; font-weight: 600;">✗ Verification failed</p>
        <p class="text-sm text-ink">${this.esc(reason)}</p>
        ${trace ? `<p class="mono text-[11px] text-ink-soft">fbtrace_id: ${this.esc(trace)}</p>` : ""}
        <p class="text-[11px] text-ink-soft">Common causes: wrong pixel ID, expired/revoked access token, or a malformed token.</p>
      </div>
    `
  }

  formatError(msg) {
    return `<p style="color: #a83a22;">✗ ${this.esc(msg)}</p>`
  }

  // Collapsible <details> block with the JSON Meta received. Helps debug
  // mismatches between what we sent vs what Meta's Test Events tab shows.
  payloadBlock(payload) {
    if (!payload) return ""
    const json = JSON.stringify(payload, null, 2)
    return `
      <details class="mt-2 text-[11px]">
        <summary class="cursor-pointer text-ink-soft hover:text-ink">View request payload</summary>
        <pre class="mono mt-2 max-h-72 overflow-auto whitespace-pre-wrap rounded bg-panel p-3 ring-1 ring-[var(--color-line-2)]">${this.esc(json)}</pre>
      </details>
    `
  }

  // ── Plumbing ───────────────────────────────────────────────────────────
  async post(url) {
    const csrf = document.querySelector('meta[name="csrf-token"]')?.content
    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Accept": "application/json",
        "Content-Type": "application/json",
        ...(csrf ? { "X-CSRF-Token": csrf } : {})
      },
      credentials: "same-origin"
    })
    return response.json().catch(() => ({}))
  }

  show() {
    if (this.hasResultTarget) this.resultTarget.classList.remove("hidden")
  }

  render(html) {
    if (this.hasResultTarget) this.resultTarget.innerHTML = html
  }

  setBusy(busy) {
    if (this.hasButtonTarget) this.buttonTarget.disabled = busy
  }

  setVerifyBusy(busy) {
    if (this.hasVerifyButtonTarget) this.verifyButtonTarget.disabled = busy
  }

  esc(s) {
    const str = String(s ?? "")
    return str
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;")
      .replace(/"/g, "&quot;")
      .replace(/'/g, "&#39;")
  }
}
