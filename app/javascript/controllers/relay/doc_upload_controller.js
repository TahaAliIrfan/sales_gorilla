// app/javascript/controllers/relay/doc_upload_controller.js
// Lets the rail's "Upload" icon button trigger the hidden multi-file input,
// then auto-submits the existing upload_documents form on selection.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "form"]

  pick() {
    this.inputTarget.click()
  }

  submit() {
    if (this.inputTarget.files.length) this.formTarget.requestSubmit()
  }
}
