// app/javascript/controllers/relay/call_trigger_controller.js
//
// A trigger that fires a window "relay:call" CustomEvent picked up by the global
// relay--callbar controller. Attach to any Call button with the customer id /
// name / phone values; clicking starts a real Twilio call in-context.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { customerId: String, name: String, phone: String }

  call(event) {
    event.preventDefault()
    window.dispatchEvent(new CustomEvent("relay:call", {
      detail: {
        customerId: this.customerIdValue,
        name: this.nameValue,
        phone: this.phoneValue
      }
    }))
  }
}
