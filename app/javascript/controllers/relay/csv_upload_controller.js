// app/javascript/controllers/relay/csv_upload_controller.js
// CSV import step 1: reflect the chosen filename in the dropzone hint and let
// drag-and-drop populate the hidden <input type=file>. Submission is a normal
// multipart POST handled by CsvImportsController#upload.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "hint", "zone", "submit"]

  connect() {
    this.over = this.over.bind(this)
    this.leave = this.leave.bind(this)
    this.drop = this.drop.bind(this)
    this.zoneTarget.addEventListener("dragover", this.over)
    this.zoneTarget.addEventListener("dragleave", this.leave)
    this.zoneTarget.addEventListener("drop", this.drop)
  }

  disconnect() {
    this.zoneTarget.removeEventListener("dragover", this.over)
    this.zoneTarget.removeEventListener("dragleave", this.leave)
    this.zoneTarget.removeEventListener("drop", this.drop)
  }

  over(e) { e.preventDefault(); this.zoneTarget.style.borderColor = "var(--color-primary)" }
  leave() { this.zoneTarget.style.borderColor = "" }

  drop(e) {
    e.preventDefault()
    this.zoneTarget.style.borderColor = ""
    if (e.dataTransfer.files && e.dataTransfer.files.length) {
      this.inputTarget.files = e.dataTransfer.files
      this.picked()
    }
  }

  picked() {
    const f = this.inputTarget.files && this.inputTarget.files[0]
    if (f) this.hintTarget.textContent = `${f.name} · ${(f.size / 1024).toFixed(0)} KB`
  }
}
