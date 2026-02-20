import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { customerId: Number }

  async markGood() {
    await this.mark("good")
  }

  async markBad() {
    await this.mark("bad")
  }

  async mark(quality) {
    const button = event.currentTarget
    const originalText = button.textContent
    button.disabled = true
    button.textContent = "..."

    try {
      const response = await fetch(`/customers/${this.customerIdValue}/mark_lead_quality`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
        },
        body: JSON.stringify({ quality })
      })

      if (response.ok) {
        window.location.reload()
      } else {
        const data = await response.json()
        alert(data.error || "Failed to update lead quality")
        button.disabled = false
        button.textContent = originalText
      }
    } catch (error) {
      console.error("Error marking lead quality:", error)
      alert("Failed to update lead quality")
      button.disabled = false
      button.textContent = originalText
    }
  }
}
