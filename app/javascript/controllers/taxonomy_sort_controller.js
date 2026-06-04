import { Controller } from "@hotwired/stimulus"

// Drag-reorder for a Settings > Taxonomies list. Persists the new order to
// the reorder endpoint as soon as drag ends.
export default class extends Controller {
  static values = { url: String, kind: String }

  connect() {
    if (!window.Sortable) {
      console.warn("Sortable.js is not loaded; taxonomy-sort drag-reorder disabled.")
      return
    }
    this.sortable = window.Sortable.create(this.element, {
      handle: ".taxonomy-sort-handle",
      animation: 150,
      onEnd: () => this.persist()
    })
  }

  disconnect() {
    this.sortable?.destroy()
  }

  async persist() {
    const ids = Array.from(this.element.querySelectorAll("[data-id]")).map((el) => el.dataset.id)
    const csrf = document.querySelector('meta[name="csrf-token"]')?.content
    const body = new FormData()
    body.append("kind", this.kindValue)
    ids.forEach((id) => body.append("ids[]", id))

    try {
      const response = await fetch(this.urlValue, {
        method: "POST",
        body,
        headers: csrf ? { "X-CSRF-Token": csrf } : {},
        credentials: "same-origin"
      })
      if (!response.ok) console.error("Reorder failed:", response.status)
    } catch (e) {
      console.error("Reorder failed:", e)
    }
  }
}
