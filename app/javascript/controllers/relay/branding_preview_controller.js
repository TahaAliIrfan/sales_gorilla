// app/javascript/controllers/relay/branding_preview_controller.js
//
// Live white-label preview for Settings → Branding. As the primary colour
// changes, recompute the 11-stop --brand-* oklch ramp and set it ONLY on the
// preview wrapper element — so the real app does not reskin until the form is
// saved server-side.
//
// The ramp math (lightness curve L, per-stop chroma multipliers CMUL, steps,
// chroma clamp) is the SAME source of truth as Relay::ThemeHelper: those Ruby
// constants are emitted into this controller's values, so JS and the server-
// rendered <style> tag stay in sync. The sRGB-hex → OKLCh conversion is a
// direct port of Relay::ThemeHelper#relay_hex_to_oklch (Björn Ottosson OKLab).
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["preview", "primary", "accent", "name", "logoLabel"]
  static values = {
    l: Array,
    cmul: Array,
    steps: Array,
    chromaMin: Number,
    chromaMax: Number
  }

  connect() {
    // Paint once from the current hex so the preview reflects the saved colour.
    if (this.hasPrimaryTarget) this.#applyHex(this.primaryTarget.value)
  }

  // Native <input type="color"> → mirror into the hex text field + repaint.
  syncPrimary(event) {
    if (this.hasPrimaryTarget) this.primaryTarget.value = event.target.value
    this.#applyHex(event.target.value)
  }

  // Hex text field typed directly.
  syncPrimaryHex(event) {
    this.#applyHex(event.target.value)
  }

  // Accent isn't part of the brand ramp; nothing to recompute, but keep the
  // colour input and hex field in sync for ergonomics.
  syncAccent(event) {
    if (this.hasAccentTarget) this.accentTarget.value = event.target.value
  }

  syncAccentHex() {
    // no-op: accent doesn't drive the ramp; saved server-side as-is.
  }

  syncName(event) {
    if (this.hasLogoLabelTarget) {
      this.logoLabelTarget.textContent = (event.target.value || "Relay").slice(0, 7)
    }
  }

  #applyHex(hex) {
    if (!this.#isHex(hex)) return
    const [, c0, h] = this.#hexToOklch(hex)
    const c = Math.min(Math.max(c0, this.chromaMinValue), this.chromaMaxValue)
    const el = this.hasPreviewTarget ? this.previewTarget : this.element
    this.stepsValue.forEach((step, i) => {
      const chroma = (c * this.cmulValue[i]).toFixed(3)
      el.style.setProperty(`--brand-${step}`, `oklch(${this.lValue[i]} ${chroma} ${h.toFixed(1)})`)
    })
  }

  #isHex(value) {
    return /^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$/.test((value || "").trim())
  }

  // Port of Relay::ThemeHelper#relay_hex_to_oklch → [lightness, chroma, hueDeg].
  #hexToOklch(hex) {
    let h = hex.replace("#", "").trim()
    if (h.length === 3) h = h.split("").map((ch) => ch + ch).join("")
    const lin = (n) => {
      const v = parseInt(n, 16) / 255
      return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
    }
    const r = lin(h.slice(0, 2))
    const g = lin(h.slice(2, 4))
    const b = lin(h.slice(4, 6))

    const l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    const m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    const s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    const l_ = Math.cbrt(l)
    const m_ = Math.cbrt(m)
    const s_ = Math.cbrt(s)

    const labL = 0.2104542553 * l_ + 0.793617785 * m_ - 0.0040720468 * s_
    const labA = 1.9779984951 * l_ - 2.428592205 * m_ + 0.4505937099 * s_
    const labB = 0.0259040371 * l_ + 0.7827717662 * m_ - 0.808675766 * s_

    const chroma = Math.sqrt(labA * labA + labB * labB)
    let hue = (Math.atan2(labB, labA) * 180) / Math.PI
    if (hue < 0) hue += 360
    return [labL, chroma, hue]
  }
}
