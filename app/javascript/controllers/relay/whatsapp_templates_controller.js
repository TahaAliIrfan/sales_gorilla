// Approved WhatsApp templates picker for the Relay lead-workspace composer.
// Talks to the same JSON endpoints as the full WhatsApp panel
// (/whatsapp_us/templates + /whatsapp_us/send_template), so admins/associates
// can fire an approved template whether the 24-hour window is open or closed.
// On success the page reloads so the new outbound bubble joins the canvas.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values  = { customerId: Number, isAdmin: Boolean, customerFields: Object }
  static targets = ["modal", "list", "error", "notice", "syncButton"]

  connect() {
    this.onKeydown = (e) => { if (e.key === "Escape") this.close() }
  }

  disconnect() {
    document.removeEventListener("keydown", this.onKeydown)
  }

  get csrfToken() {
    return document.querySelector('[name="csrf-token"]')?.content || ""
  }

  open() {
    this.modalTarget.classList.remove("hidden")
    document.addEventListener("keydown", this.onKeydown)
    this.hideError(); this.hideNotice()
    this.loadTemplates()
  }

  close() {
    this.modalTarget.classList.add("hidden")
    document.removeEventListener("keydown", this.onKeydown)
  }

  backdrop(e) {
    if (e.target === this.modalTarget) this.close()
  }

  async loadTemplates() {
    this.listTarget.innerHTML =
      `<div class="flex justify-center items-center py-8 text-gray-500 text-sm">Loading templates…</div>`
    try {
      const res  = await fetch(`/customers/${this.customerIdValue}/whatsapp_us/templates`, {
        headers: { Accept: "application/json", "X-CSRF-Token": this.csrfToken }
      })
      const data = await res.json()
      if (!res.ok) throw new Error(data.error || "Failed to load templates")
      this.renderTemplates(data.templates || [])
    } catch (e) {
      this.showError(e.message || "Failed to load templates")
    }
  }

  async sync() {
    if (!this.hasSyncButtonTarget) return
    this.syncButtonTarget.disabled = true
    this.hideError(); this.hideNotice()
    try {
      const res  = await fetch(`/customers/${this.customerIdValue}/whatsapp_us/templates/sync`, {
        method: "POST",
        headers: { Accept: "application/json", "X-CSRF-Token": this.csrfToken }
      })
      const data = await res.json()
      if (!res.ok || !data.success) throw new Error(data.error || "Sync failed")
      this.showNotice(`Synced ${data.synced} approved template(s) (skipped ${data.skipped}).`)
      this.renderTemplates(data.templates || [])
    } catch (e) {
      this.showError(e.message || "Sync failed")
    } finally {
      this.syncButtonTarget.disabled = false
    }
  }

  renderTemplates(templates) {
    if (templates.length === 0) {
      this.listTarget.innerHTML = `
        <div class="muted rl-sm" style="text-align:center;padding:32px 0">
          No approved templates yet.${this.isAdminValue ? ' Click "Sync from Twilio" to fetch them.' : ""}
        </div>`
      return
    }
    this.listTarget.innerHTML = templates.map((t) => this.templateCard(t)).join("")
  }

  templateCard(t) {
    const textKeys = t.text_variable_keys || t.variable_keys || []
    const vars     = textKeys.map((k) => this.variableRow(k)).join("")

    const mediaInput = t.requires_media_upload ? `
      <div class="rl-field" style="margin-top:var(--space-3)">
        <label class="rl-label">Attach file <span class="rl-req">*</span></label>
        <input type="file" data-template-file="true" data-required="true"
               accept="image/*,video/mp4,audio/*,.pdf,.doc,.docx,.xls,.xlsx,.pptx,.txt,.csv,.json,.xml,.zip"
               class="rl-input" style="padding:6px 8px;height:auto" />
        <p class="rl-help">This template needs a media attachment. Max 16MB.</p>
      </div>` : (t.has_media ? `
      <div class="rl-sm"
           style="margin-top:var(--space-3);padding:10px 12px;background:var(--color-warning-subtle);border:1px solid var(--color-warning-border);color:var(--color-warning-text);border-radius:var(--radius-md)">
        Twilio locked the media URL on this template at approval time, so per-send file uploads aren't possible.
      </div>` : "")

    return `
      <div data-template-sid="${this.escape(t.content_sid)}"
           style="border:1px solid var(--color-border);background:var(--color-surface);border-radius:var(--radius-lg);padding:var(--space-4);margin-bottom:var(--space-3)">
        <div class="row spread" style="gap:var(--space-3);align-items:flex-start">
          <div style="min-width:0;flex:1">
            <div class="rl-sm" style="font-weight:var(--weight-semibold);color:var(--color-fg);overflow:hidden;text-overflow:ellipsis;white-space:nowrap">
              ${this.escape(t.friendly_name || t.content_sid)}
              ${t.has_media ? `<span class="rl-badge rl-badge--info" style="margin-left:6px">MEDIA</span>` : ""}
            </div>
            <div class="muted" style="font-size:11px;margin-top:2px">
              ${this.escape(t.language || "")}${t.category ? " · " + this.escape(t.category) : ""}
            </div>
          </div>
          <button type="button" data-action="click->relay--whatsapp-templates#sendTemplate"
                  class="rl-btn rl-btn--primary rl-btn--sm" style="background:var(--channel-whatsapp);color:#fff;flex:none">
            Send
          </button>
        </div>
        ${t.body ? `<div class="rl-sm" style="margin-top:var(--space-3);padding:8px 10px;background:var(--color-surface-2);border:1px solid var(--color-border);border-radius:var(--radius-md);white-space:pre-wrap;word-break:break-word;color:var(--color-fg-2)">${this.escape(t.body)}</div>` : ""}
        ${mediaInput}
        ${vars}
      </div>`
  }

  variableRow(key) {
    const fields    = this.customerFieldsValue || {}
    const autoField = this.customerFieldFor(key)
    const autoValue = autoField && fields[autoField] ? fields[autoField] : ""

    const option = (val, label, selected) =>
      `<option value="${this.escape(val)}"${selected ? " selected" : ""}>${this.escape(label)}</option>`

    const options = [
      option("", "Manual", !autoField),
      fields.name    !== undefined ? option("name",    `Customer name (${fields.name || "—"})`,    autoField === "name")    : "",
      fields.phone   !== undefined ? option("phone",   `Customer phone (${fields.phone || "—"})`,  autoField === "phone")   : "",
      fields.email   !== undefined ? option("email",   `Customer email (${fields.email || "—"})`,  autoField === "email")   : "",
      fields.company !== undefined ? option("company", `Customer company (${fields.company || "—"})`, autoField === "company") : ""
    ].join("")

    return `
      <div class="rl-field" style="margin-top:var(--space-3)">
        <label class="rl-label">Variable {{${this.escape(key)}}}</label>
        <div class="row" style="gap:var(--space-2);align-items:stretch">
          <select data-action="change->relay--whatsapp-templates#variableSourceChanged"
                  data-var-source-for="${this.escape(key)}"
                  class="rl-select rl-input--sm" style="width:180px;flex:none">
            ${options}
          </select>
          <input type="text" data-var-key="${this.escape(key)}"
                 value="${this.escape(autoValue)}"
                 class="rl-input rl-input--sm" style="flex:1;min-width:0"
                 placeholder="Value for {{${this.escape(key)}}}" />
        </div>
      </div>`
  }

  customerFieldFor(key) {
    const k = String(key).toLowerCase()
    if (["name", "first_name", "firstname", "customer_name", "fullname", "full_name"].includes(k)) return "name"
    if (["phone", "mobile", "phone_number", "phonenumber"].includes(k)) return "phone"
    if (["email", "email_address"].includes(k)) return "email"
    if (["company", "organization", "org", "company_name"].includes(k)) return "company"
    return null
  }

  variableSourceChanged(event) {
    const sel   = event.currentTarget
    const key   = sel.dataset.varSourceFor
    const input = sel.closest(".mt-2")?.querySelector(`input[data-var-key="${CSS.escape(key)}"]`)
    if (!input) return
    const field  = sel.value
    const fields = this.customerFieldsValue || {}
    if (field && fields[field] != null) input.value = fields[field]
  }

  async sendTemplate(event) {
    const card = event.currentTarget.closest("[data-template-sid]")
    if (!card) return

    const contentSid = card.dataset.templateSid
    const variables  = {}
    card.querySelectorAll("input[data-var-key]").forEach((el) => {
      if (el.value.trim()) variables[el.dataset.varKey] = el.value.trim()
    })

    const fileInput = card.querySelector('input[data-template-file="true"]')
    const file      = fileInput?.files?.[0] || null
    if (fileInput?.dataset.required === "true" && !file) {
      this.showError("Please choose a file before sending this template.")
      return
    }

    const btn = event.currentTarget
    btn.disabled = true
    this.hideError()

    try {
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

      const res  = await fetch(`/customers/${this.customerIdValue}/whatsapp_us/send_template`, {
        method: "POST", headers, body: payload
      })
      const data = await res.json()
      if (!res.ok || !data.success) throw new Error(data.error || "Failed to send template")
      window.location.reload()
    } catch (e) {
      this.showError(e.message || "Failed to send template")
    } finally {
      btn.disabled = false
    }
  }

  showError(message) {
    if (!this.hasErrorTarget) return
    this.errorTarget.textContent = message
    this.errorTarget.classList.remove("hidden")
  }
  hideError()  { if (this.hasErrorTarget)  this.errorTarget.classList.add("hidden") }
  showNotice(message) {
    if (!this.hasNoticeTarget) return
    this.noticeTarget.textContent = message
    this.noticeTarget.classList.remove("hidden")
  }
  hideNotice() { if (this.hasNoticeTarget) this.noticeTarget.classList.add("hidden") }

  escape(str) {
    const div = document.createElement("div")
    div.textContent = str == null ? "" : String(str)
    return div.innerHTML
  }
}
