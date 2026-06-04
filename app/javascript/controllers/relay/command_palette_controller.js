// app/javascript/controllers/relay/command_palette_controller.js
// ⌘K palette: open/close, filter, arrow-key selection, enter to follow.
// Lives on <body>; the topbar search box and keydown@window route here.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["scrim", "input", "list", "item", "group", "blank"]

  keydown(e) {
    if ((e.metaKey || e.ctrlKey) && e.key.toLowerCase() === "k") { e.preventDefault(); this.toggle() }
    else if (e.key === "Escape" && !this.scrimTarget.hidden) this.close()
  }

  open() {
    this.scrimTarget.hidden = false
    this.inputTarget.value = ""
    this.filter()
    setTimeout(() => this.inputTarget.focus(), 30)
  }

  close() { this.scrimTarget.hidden = true }
  toggle() { this.scrimTarget.hidden ? this.open() : this.close() }
  backdrop(e) { if (e.target === this.scrimTarget) this.close() }

  filter() {
    const q = this.inputTarget.value.trim().toLowerCase()
    let any = false
    this.itemTargets.forEach((el) => {
      const hit = !q || el.dataset.label.includes(q)
      el.hidden = !hit
      if (hit) any = true
    })
    this.groupTargets.forEach((g) => {
      g.hidden = !g.querySelector("[data-relay--command-palette-target='item']:not([hidden])")
    })
    this.blankTarget.hidden = any
    this.select(0)
  }

  navigate(e) {
    const visible = this.itemTargets.filter((el) => !el.hidden)
    if (e.key === "ArrowDown") { e.preventDefault(); this.select(Math.min(this.index + 1, visible.length - 1)) }
    else if (e.key === "ArrowUp") { e.preventDefault(); this.select(Math.max(this.index - 1, 0)) }
    else if (e.key === "Enter") { e.preventDefault(); visible[this.index]?.click(); this.close() }
  }

  select(i) {
    this.index = i
    this.itemTargets.filter((el) => !el.hidden).forEach((el, j) => {
      el.classList.toggle("is-active", j === i)
      if (j === i) el.scrollIntoView({ block: "nearest" })
    })
  }
}
