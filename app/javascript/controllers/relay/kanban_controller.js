// app/javascript/controllers/relay/kanban_controller.js
// Pipeline board: SortableJS drag of deal cards between stage columns.
// On drop, PATCH the deals#update_stage endpoint (JSON { deal_stage_id }).
// Optimistic — the card has already moved in the DOM; on failure we put it back
// and surface a toast. Column counts/value totals are recomputed client-side
// after a confirmed move.
import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["column"]
  static values = { url: String } // e.g. "/deals/:id/update_stage"

  connect() {
    this.sortables = this.columnTargets.map((col) =>
      Sortable.create(col, {
        group: "pipeline",
        animation: 150,
        draggable: ".rl-dealcard",
        ghostClass: "is-dragging",
        onEnd: (evt) => this.onEnd(evt),
      })
    )
  }

  disconnect() {
    ;(this.sortables || []).forEach((s) => s.destroy())
    this.sortables = []
  }

  onEnd(evt) {
    const card = evt.item
    const toCol = evt.to
    const fromCol = evt.from
    if (toCol === fromCol) return

    const dealId = card.dataset.dealId
    const stageId = toCol.dataset.stageId
    if (!dealId || !stageId) return

    const url = this.urlValue.replace(":id", dealId)
    const token = document.querySelector('meta[name="csrf-token"]')?.content

    fetch(url, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": token || "",
      },
      body: JSON.stringify({ deal_stage_id: stageId }),
    })
      .then((res) => (res.ok ? res.json() : Promise.reject(res)))
      .then((data) => {
        if (!data.success) return Promise.reject(data)
        this.recount(fromCol)
        this.recount(toCol)
        this.toast(`Moved to ${toCol.dataset.stageName || "stage"}`, "success")
      })
      .catch(() => {
        // Revert: drop the card back into its origin column at its old index.
        const ref = fromCol.children[evt.oldIndex] || null
        fromCol.insertBefore(card, ref)
        this.toast("Couldn't move deal — reverted", "danger")
      })
  }

  // Recompute "count" badge and the column value total from the cards present.
  recount(col) {
    const cards = col.querySelectorAll(".rl-dealcard")

    // Show/hide the "No deals" placeholder so it never sits beside real cards.
    const placeholder = col.querySelector(".rl-col__empty")
    if (placeholder) placeholder.hidden = cards.length > 0

    const head = col.closest(".rl-col")
    const countEl = head?.querySelector("[data-kanban-count]")
    if (countEl) countEl.textContent = cards.length

    const totalEl = head?.querySelector("[data-kanban-total]")
    if (totalEl) {
      let sum = 0
      cards.forEach((c) => (sum += Number(c.dataset.value || 0)))
      totalEl.textContent = this.money(sum)
    }
  }

  money(n) {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD",
      maximumFractionDigits: 0,
    }).format(n)
  }

  toast(message, kind) {
    const wrap = document.getElementById("relay_toasts")
    if (!wrap) return
    const el = document.createElement("div")
    el.className = `toast toast--${kind}`
    el.textContent = message
    el.setAttribute("data-relay--toast-target", "item")
    wrap.appendChild(el)
    // Fallback auto-dismiss in case the toast controller isn't watching.
    setTimeout(() => {
      el.style.transition = "opacity .3s var(--ease-out)"
      el.style.opacity = "0"
      setTimeout(() => el.remove(), 300)
    }, 2600)
  }
}
