// app/javascript/controllers/relay/bulk_select_controller.js
// Drives the Leads table bulk selection + bulk bar. Header checkbox toggles
// all rows; row checkboxes update the count and show/hide the bulk bar.
// Actions submit the selected ids to the existing bulk_assign /
// bulk_status_change endpoints via hidden forms (CSRF-safe, server redirects).
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "all", "checkbox", "row", "bar", "count",
    "assignForm", "assignIds", "assignUser",
    "statusForm", "statusIds", "statusValue",
  ]
  static values = { assignUrl: String, statusUrl: String }

  // --- selection -----------------------------------------------------------
  toggleAll() {
    const checked = this.allTarget.checked
    this.checkboxTargets.forEach((cb) => { cb.checked = checked })
    this.sync()
  }

  toggleRow() { this.sync() }

  clear() {
    this.checkboxTargets.forEach((cb) => { cb.checked = false })
    if (this.hasAllTarget) this.allTarget.checked = false
    this.sync()
  }

  sync() {
    const ids = this.selectedIds()
    const total = this.checkboxTargets.length
    if (this.hasAllTarget) {
      this.allTarget.checked = ids.length > 0 && ids.length === total
      this.allTarget.indeterminate = ids.length > 0 && ids.length < total
    }
    this.rowTargets.forEach((row) => {
      const cb = row.querySelector('[data-relay--bulk-select-target="checkbox"]')
      row.classList.toggle("is-selected", !!(cb && cb.checked))
    })
    if (this.hasBarTarget) this.barTarget.hidden = ids.length === 0
    if (this.hasCountTarget) this.countTarget.textContent = ids.length
  }

  selectedIds() {
    return this.checkboxTargets.filter((cb) => cb.checked).map((cb) => cb.value)
  }

  // --- bulk actions --------------------------------------------------------
  assign(event) {
    const ids = this.selectedIds()
    if (!ids.length) return
    const userId = event.currentTarget.dataset.userId
    this.assignIdsTarget.value = ids.join(",")
    this.assignUserTarget.value = userId
    this.assignFormTarget.requestSubmit()
  }

  changeStatus(event) {
    const ids = this.selectedIds()
    if (!ids.length) return
    const status = event.currentTarget.dataset.status
    this.statusIdsTarget.value = ids.join(",")
    this.statusValueTarget.value = status
    this.statusFormTarget.requestSubmit()
  }

  // Export the current filtered set with the ids appended so the server can
  // narrow the CSV (export_csv reuses the same filters; ids are advisory).
  exportSelected() {
    const ids = this.selectedIds()
    const url = new URL(window.location.href)
    url.pathname = url.pathname.replace(/\/?$/, "") + "/export_csv"
    if (ids.length) url.searchParams.set("ids", ids.join(","))
    window.location.href = url.toString()
  }
}
