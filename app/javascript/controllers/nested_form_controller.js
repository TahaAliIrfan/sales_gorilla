import { Controller } from "@hotwired/stimulus"

// Adds/removes rows for a nested_attributes association (e.g. invoice payment links).
// Markup:
//   data-controller="nested-form"
//   <div data-nested-form-target="list"> ... existing rows ... </div>
//   <template data-nested-form-target="template"> row html with NEW_RECORD placeholder </template>
//   <button data-action="nested-form#add">Add</button>
//   each row wrapper: data-nested-form-target="item" with a remove button data-action="nested-form#remove"
export default class extends Controller {
  static targets = ["list", "template"]

  add(event) {
    event.preventDefault()
    const html = this.templateTarget.innerHTML.replace(/NEW_RECORD/g, new Date().getTime().toString())
    this.listTarget.insertAdjacentHTML("beforeend", html)
  }

  remove(event) {
    event.preventDefault()
    const item = event.target.closest("[data-nested-form-target='item']")
    if (!item) return

    const destroyField = item.querySelector("input[name*='_destroy']")
    if (destroyField) {
      // Persisted record: flag for destruction and hide it.
      destroyField.value = "1"
      item.style.display = "none"
    } else {
      // Unsaved row: just drop it from the DOM.
      item.remove()
    }
  }
}
