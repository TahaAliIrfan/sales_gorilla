import { Controller } from "@hotwired/stimulus"

// Global floating softphone. Mounted once on the dashboard layout wrapper, so
// any "Call" button inside the app can dial without leaving the page:
//
//   <button data-action="call-widget#call"
//           data-call-phone="+1..." data-call-customer-id="42" data-call-name="Jane">
//
// Reuses the existing /calling/token + /calling/store_customer_id endpoints and
// the Twilio Voice SDK (lazy-loaded on first call).
const SDK_URL = "https://cdn.jsdelivr.net/npm/@twilio/voice-sdk@2.15.0/dist/twilio.min.js"
const DEFAULT_CALLER_ID = "+447897021964"

export default class extends Controller {
  static targets = ["panel", "name", "number", "status", "timer", "muteBtn",
                    "chooser", "numbers", "preferredNote", "callBtn", "live"]
  static values = { defaultCallerId: String }

  connect() {
    this.device = null
    this.currentCall = null
    this.deviceReady = false
    this.timerInterval = null
    this.seconds = 0
    this.pending = null // { phone, customerId, name }
  }

  disconnect() {
    this._stopTimer()
  }

  // Entry point — triggered by any Call button. Opens the picker; we dial only
  // once the rep confirms a caller ID (see confirmCall).
  async call(event) {
    event.preventDefault()
    const el = event.currentTarget
    const phone = el.dataset.callPhone
    const customerId = el.dataset.callCustomerId
    const name = el.dataset.callName || phone
    if (!phone) return
    if (this.currentCall) return // already on a call

    this.pending = { phone, customerId, name }
    this._open(name, phone)
    this._showChooser()
    await this._loadNumbers(customerId)
  }

  // Fetch owned numbers for this lead and render them, preferred one preselected.
  async _loadNumbers(customerId) {
    this.numbersTarget.innerHTML = `<div class="cw-loading">Finding the best number…</div>`
    this.callBtnTarget.disabled = true
    if (this.hasPreferredNoteTarget) this.preferredNoteTarget.textContent = ""

    try {
      const url = customerId ? `/calling/available_numbers?customer_id=${encodeURIComponent(customerId)}` : "/calling/available_numbers"
      const res = await fetch(url, { headers: { Accept: "application/json" } })
      if (!res.ok) throw new Error(`numbers ${res.status}`)
      const data = await res.json()
      this._renderNumbers(data)
    } catch (e) {
      // Fall back to dialing with the saved default so calling still works.
      this._renderNumbers({
        numbers: [{ phone_number: this._callerId(), label: "Default", preferred: true }],
        preferred: this._callerId(),
        preferred_note: "",
      })
    }
    this.callBtnTarget.disabled = false
  }

  _renderNumbers(data) {
    const numbers = Array.isArray(data.numbers) ? data.numbers : []
    const preferred = data.preferred
    this.numbersTarget.innerHTML = ""

    numbers.forEach((n) => {
      const checked = n.phone_number === preferred
      const row = document.createElement("label")
      row.className = "cw-opt" + (checked ? " is-preferred" : "")
      row.innerHTML = `
        <input type="radio" name="cw-caller" value="${n.phone_number}" ${checked ? "checked" : ""}>
        <span class="cw-opt-main">
          <span class="cw-opt-label">${n.label || ""}</span>
          <span class="cw-opt-num cb-mono">${n.phone_number}</span>
        </span>
        ${n.preferred ? '<span class="cw-badge">Recommended</span>' : ""}`
      this.numbersTarget.appendChild(row)
    })

    if (this.hasPreferredNoteTarget) {
      this.preferredNoteTarget.textContent = data.preferred_note || ""
    }
  }

  // Step 2: dial with the caller ID the rep chose.
  async confirmCall() {
    if (!this.pending || this.currentCall) return
    const chosen = this.numbersTarget.querySelector('input[name="cw-caller"]:checked')
    const callerId = chosen ? chosen.value : this._callerId()
    const { phone, customerId } = this.pending

    this._showLive()
    this._status("Connecting…", "info")

    try {
      await this._ensureDevice()
    } catch (e) {
      this._status(`Phone service unavailable: ${e.message}`, "error")
      return
    }

    if (customerId) {
      fetch("/calling/store_customer_id", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": this._csrf() },
        body: JSON.stringify({ customer_id: customerId }),
      }).catch(() => {})
    }

    try {
      this.currentCall = await this.device.connect({
        params: { To: phone, caller_id: callerId, customer_id: customerId || "" },
      })
      this._bindCall()
      this._status("Ringing…", "info")
    } catch (e) {
      this._status(`Failed to connect: ${e.message}`, "error")
      this.currentCall = null
    }
  }

  hangup() {
    if (this.currentCall) this.currentCall.disconnect()
  }

  toggleMute() {
    if (!this.currentCall) return
    const muted = !this.currentCall.isMuted()
    this.currentCall.mute(muted)
    if (this.hasMuteBtnTarget) {
      this.muteBtnTarget.classList.toggle("is-muted", muted)
      this.muteBtnTarget.textContent = muted ? "Unmute" : "Mute"
    }
  }

  close() {
    if (this.currentCall) return // never close mid-call
    clearTimeout(this._closeTimeout)
    this.pending = null
    this.panelTarget.classList.remove("cw-visible")
    setTimeout(() => this.panelTarget.classList.add("hidden"), 200)
  }

  // ---- internals ----

  _showChooser() {
    if (this.hasChooserTarget) this.chooserTarget.classList.remove("hidden")
    if (this.hasLiveTarget) this.liveTarget.classList.add("hidden")
  }

  _showLive() {
    if (this.hasChooserTarget) this.chooserTarget.classList.add("hidden")
    if (this.hasLiveTarget) this.liveTarget.classList.remove("hidden")
  }

  async _ensureDevice() {
    if (this.device && this.deviceReady) return
    await this._loadSdk()
    const res = await fetch("/calling/token")
    if (!res.ok) throw new Error(`token ${res.status}`)
    const data = await res.json()
    const token = data.data?.token || data.token
    if (!token) throw new Error("no token")
    this.device = new window.Twilio.Device(token, { logLevel: 1, codecPreferences: ["opus", "pcmu"] })
    this.device.on("error", (e) => this._status(`Device error: ${e.message || e.code}`, "error"))
    this.deviceReady = true
  }

  _loadSdk() {
    return new Promise((resolve, reject) => {
      if (window.Twilio && window.Twilio.Device) return resolve()
      const s = document.createElement("script")
      s.src = SDK_URL
      s.onload = () => (window.Twilio && window.Twilio.Device ? resolve() : reject(new Error("SDK unavailable")))
      s.onerror = () => reject(new Error("SDK network error"))
      document.head.appendChild(s)
    })
  }

  _bindCall() {
    const c = this.currentCall
    c.on("accept", () => { this._status("In call", "success"); this._startTimer() })
    c.on("disconnect", () => { this._status("Call ended", "info"); this._endCall() })
    c.on("cancel", () => { this._status("Cancelled", "info"); this._endCall() })
    c.on("reject", () => { this._status("Rejected", "warn"); this._endCall() })
    c.on("error", (e) => { this._status(`Error: ${e.message || ""}`, "error"); this._endCall() })
  }

  _endCall() {
    this.currentCall = null
    this._stopTimer()
    if (this.hasMuteBtnTarget) { this.muteBtnTarget.classList.remove("is-muted"); this.muteBtnTarget.textContent = "Mute" }
    this._closeTimeout = setTimeout(() => this.close(), 2500)
  }

  _open(name, number) {
    clearTimeout(this._closeTimeout)
    this.nameTarget.textContent = name
    this.numberTarget.textContent = number
    this.timerTarget.textContent = "0:00"
    this.panelTarget.classList.remove("hidden")
    requestAnimationFrame(() => this.panelTarget.classList.add("cw-visible"))
  }

  _startTimer() {
    this.seconds = 0
    this._stopTimer()
    this.timerInterval = setInterval(() => {
      this.seconds++
      const m = Math.floor(this.seconds / 60)
      const s = (this.seconds % 60).toString().padStart(2, "0")
      this.timerTarget.textContent = `${m}:${s}`
    }, 1000)
  }

  _stopTimer() {
    if (this.timerInterval) clearInterval(this.timerInterval)
    this.timerInterval = null
  }

  _status(msg, type = "info") {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = msg
    this.statusTarget.dataset.state = type
  }

  // Caller ID = the user's saved default (rendered server-side into the layout),
  // then a same-session localStorage hint, else the fallback. The server also
  // enforces the user default in CallingController#voice as a final safety net.
  _callerId() {
    if (this.hasDefaultCallerIdValue && this.defaultCallerIdValue) return this.defaultCallerIdValue
    try {
      return localStorage.getItem("crm.defaultCallerId") || DEFAULT_CALLER_ID
    } catch (e) {
      return DEFAULT_CALLER_ID
    }
  }

  _csrf() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
