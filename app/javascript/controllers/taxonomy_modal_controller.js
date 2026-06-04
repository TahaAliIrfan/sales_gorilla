import { Controller } from "@hotwired/stimulus"

// Delete-confirmation modal for taxonomy values. Opened with a row's id +
// name; fetches usage count and sibling values from the server, then shows a
// reassignment dropdown if any customers reference the value.
export default class extends Controller {
  static targets = ["modal", "dialog", "title", "body", "form", "reassignWrap", "reassignSelect"]
  static values  = { usageUrlTemplate: String }

  async open(event) {
    const id = event.currentTarget.dataset.taxonomyId
    const name = event.currentTarget.dataset.taxonomyName

    this.titleTarget.textContent = `Delete "${name}"`
    this.bodyTarget.textContent = "Checking usage…"
    this.formTarget.classList.add("hidden")
    this.reassignWrapTarget.classList.add("hidden")
    this.show()

    try {
      const url = this.usageUrlTemplateValue.replace(":id", id)
      const response = await fetch(url, {
        headers: { Accept: "application/json" },
        credentials: "same-origin"
      })
      if (!response.ok) throw new Error(`HTTP ${response.status}`)
      const data = await response.json()
      this.render(data)
    } catch (e) {
      this.bodyTarget.textContent = `Could not load usage info: ${e.message}`
    }
  }

  render(data) {
    const baseAction = `/settings/taxonomies/${data.id}`
    this.formTarget.action = baseAction
    this.formTarget.classList.remove("hidden")

    if (data.count === 0) {
      this.bodyTarget.textContent = "No customers reference this value. It will be removed immediately."
      this.reassignWrapTarget.classList.add("hidden")
      return
    }

    if (data.siblings.length === 0) {
      this.bodyTarget.innerHTML =
        `<b>${data.count}</b> customer(s) currently use this value, and there are no other values to reassign to. ` +
        `Deleting will clear the field on those customers.`
      this.reassignWrapTarget.classList.add("hidden")
      return
    }

    this.bodyTarget.innerHTML =
      `<b>${data.count}</b> customer(s) currently use this value. Pick a replacement before deleting.`

    // Populate the reassignment select with siblings + a "leave blank" option.
    this.reassignSelectTarget.innerHTML = ""
    const optBlank = document.createElement("option")
    optBlank.value = ""
    optBlank.textContent = "— Leave blank (clear field) —"
    this.reassignSelectTarget.appendChild(optBlank)

    data.siblings.forEach((name) => {
      const opt = document.createElement("option")
      opt.value = name
      opt.textContent = name
      this.reassignSelectTarget.appendChild(opt)
    })

    this.reassignWrapTarget.classList.remove("hidden")
  }

  show() {
    this.modalTarget.classList.remove("hidden")
    this.modalTarget.classList.add("flex")
  }

  close(event) {
    if (event) event.preventDefault()
    this.modalTarget.classList.add("hidden")
    this.modalTarget.classList.remove("flex")
  }

  // Click outside the dialog closes the modal.
  backdropClick(event) {
    if (this.hasDialogTarget && this.dialogTarget.contains(event.target)) return
    this.close()
  }
}
