// app/javascript/controllers/relay/callbar_controller.js
//
// The global Relay CallBar — the design's floating active-call UI wired to the
// REAL Twilio Voice SDK. Adapted from app/javascript/controllers/calling_controller.js
// (the /calling page's working Device logic) without touching it.
//
// Flow: a trigger anywhere (lead rail, leads table) dispatches a window
// CustomEvent "relay:call" with detail { customerId, name, phone }. We show the
// bar, lazy-fetch a Twilio token (no token round-trip on page load), init the
// Device, store the customer id server-side for recording attribution, then
// connect with the SAME params the old controller sends. Recording starts
// automatically server-side, so REC is a status badge (not a toggle). caller_id
// is omitted — the engine's voice action defaults it (get_verified_caller_id).
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "avatar", "name", "phone", "timer", "status", "rec",
    "keys", "muteBtn", "muteLabel", "keypadBtn"
  ]
  static values = {
    tokenUrl: String,   // /calling/token
    voiceUrl: String,   // /calling/voice (here for parity/debug; SDK uses the app's TwiML App)
    storeUrl: String    // /calling/store_customer_id
  }

  connect() {
    this.device = null
    this.currentCall = null
    this.timerId = null
    this.token = null // cached across calls within this page lifetime
    this.callConnected = false
    this.callFailed = false
    this.callEnded = false
  }

  disconnect() {
    this.teardown()
  }

  // --- entry point: window "relay:call" -----------------------------------
  async start(event) {
    const { customerId, name, phone } = event.detail || {}
    if (!phone) {
      this.toast("This lead has no phone number to call.", "danger")
      return
    }
    if (this.currentCall) {
      this.toast("A call is already in progress.", "info")
      return
    }

    this.customerId = customerId
    this.callConnected = false
    this.callFailed = false
    this.callEnded = false
    this.renderIdentity(name, phone)
    this.show()
    this.setStatus("Connecting…")
    this.resetControls()

    try {
      await this.ensureMicAccess()
      const token = await this.fetchToken()
      await this.waitForTwilioSdk()
      await this.ensureDevice(token)
      await this.storeCustomerId(customerId)
      await this.connectCall(phone, customerId)
    } catch (error) {
      console.error("CallBar start failed:", error)
      this.callFailed = true
      const msg = error.message || String(error) || "Unable to start call"
      this.setStatus(msg)
      this.toast(msg, "danger")
      this.stopTimer()
      // Keep the widget visible so the user can read the error and click End to
      // dismiss. Teardown the device so a retry re-initializes cleanly.
      if (this.currentCall) {
        try { this.currentCall.disconnect() } catch (_) {}
        this.currentCall = null
      }
    }
  }

  // Ask the browser for mic access up-front so a denied/missing/busy mic
  // produces a clear, actionable message *before* Twilio tries to acquire the
  // device. Without this the SDK throws AcquisitionFailedError (31402), which
  // is opaque to end-users. We immediately stop the tracks — the SDK will
  // acquire its own stream once the call connects.
  async ensureMicAccess() {
    this.setStatus("Requesting microphone access…")
    if (!navigator.mediaDevices?.getUserMedia) {
      // Chrome/Edge/Firefox all hide mediaDevices on insecure origins (anything
      // that isn't HTTPS or localhost). On this app that's the lvh.me dev host
      // over HTTP — the fix is to use localhost:3000, an HTTPS tunnel (ngrok),
      // or whitelist the origin in chrome://flags#unsafely-treat-insecure-origin-as-secure.
      if (window.isSecureContext === false) {
        throw new Error(
          `Calling requires a secure origin (HTTPS or localhost). This page is ${window.location.origin}. ` +
          `Open the app at http://localhost:3000 or via your HTTPS tunnel and try again.`
        )
      }
      throw new Error("Your browser doesn't expose microphone access on this page. Try Chrome, Edge, or Firefox over HTTPS.")
    }
    let stream
    try {
      stream = await navigator.mediaDevices.getUserMedia({ audio: true })
    } catch (err) {
      throw new Error(this.micErrorMessage(err))
    }
    stream.getTracks().forEach((t) => t.stop())
  }

  micErrorMessage(err) {
    switch (err?.name) {
      case "NotAllowedError":
      case "PermissionDeniedError":
        return "Microphone access was blocked. Click the 🔒 icon in your address bar, allow microphone, then try again."
      case "NotFoundError":
      case "DevicesNotFoundError":
        return "No microphone detected. Plug one in (or enable a built-in mic) and try again."
      case "NotReadableError":
      case "TrackStartError":
        return "Your microphone is being used by another app (Zoom, Meet, etc.). Close it and try again."
      case "OverconstrainedError":
      case "ConstraintNotSatisfiedError":
        return "Your microphone settings aren't compatible with calling. Check the site's mic settings in your browser."
      case "SecurityError":
        return "Microphone access requires HTTPS. Reload over HTTPS and try again."
      default:
        return `Couldn't access your microphone (${err?.name || "unknown error"}).`
    }
  }

  // --- token (lazy, cached) -----------------------------------------------
  async fetchToken() {
    if (this.token) return this.token
    const res = await fetch(this.tokenUrlValue)
    if (!res.ok) throw new Error(`token HTTP ${res.status}`)
    const data = await res.json()
    const token = data.data?.token || data.token
    if (!token) throw new Error("No token received from server")
    this.token = token
    return token
  }

  async waitForTwilioSdk(timeoutMs = 5000) {
    if (window.Twilio?.Device) return
    const start = Date.now()
    while (!window.Twilio?.Device) {
      if (Date.now() - start > timeoutMs) throw new Error("Twilio Voice SDK failed to load")
      await new Promise((r) => setTimeout(r, 50))
    }
  }

  async ensureDevice(token) {
    if (this.device) {
      try { this.device.updateToken(token) } catch (_) { /* older SDK: recreate below */ }
      return
    }
    this.device = new window.Twilio.Device(token, {
      logLevel: 1,
      codecPreferences: ["opus", "pcmu"]
    })
    this.device.on("error", (error) => {
      console.error("Device Error:", error)
      this.toast(this.deviceErrorMessage(error), "danger")
    })
  }

  deviceErrorMessage(error) {
    switch (error.code) {
      case 31002: return "Authentication error. Please refresh and try again."
      case 31003: return "Error connecting to phone service. Check your network."
      case 31005: return "Microphone access denied. Allow mic access in your browser."
      case 31008: return "Connection to phone service failed. Check your network."
      case 31009: return "Call failed — the number may be invalid or unreachable."
      default:    return `Phone error: ${error.message || "Unknown error"}`
    }
  }

  // Store the customer id in the session so recording_status can attribute the
  // recording to the right customer (parity with the old controller).
  async storeCustomerId(customerId) {
    if (!customerId) return
    try {
      await fetch(this.storeUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": this.csrfToken()
        },
        body: JSON.stringify({ customer_id: customerId })
      })
    } catch (error) {
      console.error("Error storing customer ID:", error)
      // non-fatal — the connect params also carry customer_id
    }
  }

  // --- connect ------------------------------------------------------------
  async connectCall(phone, customerId) {
    // Same param contract as calling_controller.js makeCall(). caller_id is
    // intentionally omitted: the voice action defaults it server-side.
    const params = { To: phone }
    if (customerId) params.customer_id = String(customerId)

    this.currentCall = await this.device.connect({ params })
    this.setupCallListeners()
    this.setStatus("Calling…")
  }

  setupCallListeners() {
    if (!this.currentCall) return

    this.currentCall.on("accept", () => {
      this.callConnected = true
      this.setStatus("In call")
      this.startTimer()
    })
    this.currentCall.on("disconnect", () => this.onCallEnded("disconnect"))
    this.currentCall.on("cancel", () => this.onCallEnded("cancel"))
    this.currentCall.on("reject", () => this.onCallEnded("reject"))
    this.currentCall.on("error", (error) => {
      console.error("Call error:", error)
      this.callFailed = true
      const msg = this.callErrorMessage(error)
      this.setStatus(msg)
      this.toast(msg, "danger")
      this.onCallEnded("error")
    })
  }

  callErrorMessage(error) {
    // 31402 = AcquisitionFailedError: getUserMedia rejected the constraints.
    // Usually a stale input-device id, a mic in use by another app, or no mic.
    if (error?.code === 31402) {
      return "Couldn't access your microphone. Close other apps using the mic (Zoom, Meet, etc.), check the site's mic permission, then try again."
    }
    return `Call failed: ${error?.message || "Unknown error"}`
  }

  onCallEnded(reason) {
    if (this.callEnded) return // idempotent: error + disconnect both fire
    this.callEnded = true
    this.stopTimer()
    this.currentCall = null
    // Only claim the call was logged if it actually connected and didn't error.
    // Twilio fires `disconnect` after `error`, so without this guard a failed
    // call (e.g. AcquisitionFailedError) would show a false "saved" toast.
    if (reason === "disconnect" && this.callConnected && !this.callFailed) {
      this.setStatus("Ended")
      this.toast("Call logged · recording + transcript saved", "success")
      setTimeout(() => this.hide(), 1200)
      return
    }
    // Failure / cancel / reject — keep the widget open so the user can read the
    // status and dismiss with End. (Previously this auto-hid after 1.2s, which
    // made the bar feel like it never opened when getUserMedia failed.)
    if (!this.callFailed) {
      this.setStatus(reason === "cancel" ? "Cancelled" : reason === "reject" ? "Rejected" : "Ended")
      setTimeout(() => this.hide(), 1200)
    }
  }

  // --- controls -----------------------------------------------------------
  toggleMute() {
    if (!this.currentCall) return
    const next = !this.currentCall.isMuted()
    this.currentCall.mute(next)
    this.muteBtnTarget.classList.toggle("is-on", next)
    this.muteBtnTarget.classList.toggle("is-muted", next)
    if (this.hasMuteLabelTarget) this.muteLabelTarget.textContent = next ? "Unmute" : "Mute"
  }

  toggleKeypad() {
    const open = this.keysTarget.hidden
    this.keysTarget.hidden = !open
    this.keypadBtnTarget.classList.toggle("is-on", open)
  }

  sendDigit(event) {
    const digit = event.currentTarget.dataset.digit
    if (this.currentCall && digit) this.currentCall.sendDigits(digit)
  }

  end() {
    if (this.currentCall) {
      this.currentCall.disconnect() // fires "disconnect" → onCallEnded("logged")
    } else {
      this.hide()
    }
  }

  // --- timer --------------------------------------------------------------
  startTimer() {
    this.sec = 0
    this.renderTimer()
    this.stopTimer()
    this.timerId = setInterval(() => { this.sec += 1; this.renderTimer() }, 1000)
  }

  stopTimer() {
    if (this.timerId) { clearInterval(this.timerId); this.timerId = null }
  }

  renderTimer() {
    const mm = String(Math.floor(this.sec / 60)).padStart(2, "0")
    const ss = String(this.sec % 60).padStart(2, "0")
    this.timerTarget.textContent = `${mm}:${ss}`
  }

  // --- view helpers -------------------------------------------------------
  renderIdentity(name, phone) {
    const display = name || phone || "Unknown"
    this.nameTarget.textContent = display
    this.phoneTarget.textContent = phone || ""
    this.avatarTarget.textContent = this.initials(display)
  }

  initials(name) {
    return name.toString().trim().split(/\s+/).map((w) => w[0]).join("").slice(0, 2).toUpperCase()
  }

  resetControls() {
    this.sec = 0
    this.renderTimer()
    if (this.hasKeysTarget) this.keysTarget.hidden = true
    if (this.hasKeypadBtnTarget) this.keypadBtnTarget.classList.remove("is-on")
    if (this.hasMuteBtnTarget) this.muteBtnTarget.classList.remove("is-on", "is-muted")
    if (this.hasMuteLabelTarget) this.muteLabelTarget.textContent = "Mute"
  }

  setStatus(text) {
    if (this.hasStatusTarget) this.statusTarget.textContent = text
  }

  show() { this.element.hidden = false }
  hide() {
    this.element.hidden = true
    this.setStatus("")
  }

  teardown() {
    this.stopTimer()
    if (this.currentCall) {
      try { this.currentCall.disconnect() } catch (_) {}
      this.currentCall = null
    }
    if (this.device) {
      try { this.device.destroy() } catch (_) {}
      this.device = null
    }
  }

  // --- toasts -------------------------------------------------------------
  // Inject a toast into #relay_toasts so relay--toast auto-dismisses it.
  toast(message, kind = "info") {
    const host = document.getElementById("relay_toasts")
    if (!host) return
    const el = document.createElement("div")
    el.className = `toast toast--${kind}`
    el.setAttribute("data-relay--toast-target", "item")
    el.textContent = message
    host.appendChild(el)
  }

  csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content || ""
  }
}
