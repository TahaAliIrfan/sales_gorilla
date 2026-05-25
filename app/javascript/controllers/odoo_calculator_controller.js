import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "moduleCheckbox", "moduleCount",
    "implFee", "hostingCost", "hostingRow", "totalCost",
    "deployRadio", "deployLabel",
    "tierRadio", "tierLabel", "hostingSection",
    "numUsers",
    "customerSelect", "customerName",
    "submitBtn"
  ]

  static values = { calculateUrl: String }

  connect() {
    this.updateSummary()
    this.updateDeploymentUI()
    this.highlightSelectedModules()
  }

  toggleModule(event) {
    const card = event.currentTarget
    const checkbox = card.querySelector('input[type="checkbox"]')
    // Only toggle when clicking the card, not when clicking the checkbox directly
    if (event.target !== checkbox) {
      checkbox.checked = !checkbox.checked
    }
    card.classList.toggle("selected", checkbox.checked)
    this.updateSummary()
  }

  customerChanged(event) {
    if (event.target.value) {
      this.customerNameTarget.value = ""
      this.customerNameTarget.disabled = true
      this.customerNameTarget.classList.add("opacity-50")
    } else {
      this.customerNameTarget.disabled = false
      this.customerNameTarget.classList.remove("opacity-50")
    }
  }

  deploymentChanged(event) {
    this.updateDeploymentUI()
    this.updateSummary()
  }

  tierChanged(event) {
    this.updateTierUI()
    this.updateSummary()
  }

  usersChanged() {
    // Users don't affect cost directly but update UI
  }

  incrementUsers() {
    const input = this.numUsersTarget
    input.value = Math.min(500, parseInt(input.value || 0) + 1)
  }

  decrementUsers() {
    const input = this.numUsersTarget
    input.value = Math.max(1, parseInt(input.value || 1) - 1)
  }

  updateDeploymentUI() {
    const selected = this.deployRadioTargets.find(r => r.checked)
    if (!selected) return

    const deployType = selected.dataset.deployKey

    // Update label borders
    this.deployLabelTargets.forEach(label => {
      const isSelected = label.dataset.deployKey === deployType
      label.classList.toggle("border-red-500", isSelected)
      label.classList.toggle("bg-red-50", isSelected)
      label.classList.toggle("border-gray-100", !isSelected)
    })

    // Show/hide hosting section
    const showHosting = deployType === "sh" || deployType === "on_premise"
    this.hostingSectionTarget.style.display = showHosting ? "block" : "none"

    // Show/hide hosting row in summary
    if (this.hasHostingRowTarget) {
      this.hostingRowTarget.style.display = showHosting ? "flex" : "none"
    }
  }

  updateTierUI() {
    const selected = this.tierRadioTargets.find(r => r.checked)
    if (!selected) return
    const tierKey = selected.dataset.tierKey

    this.tierLabelTargets.forEach(label => {
      const isSelected = label.dataset.tierKey === tierKey
      label.classList.toggle("border-red-500", isSelected)
      label.classList.toggle("bg-red-50", isSelected)
      label.classList.toggle("border-gray-100", !isSelected)
    })
  }

  updateSummary() {
    const selectedModules = this.moduleCheckboxTargets
      .filter(cb => cb.checked)
      .map(cb => cb.dataset.moduleKey)

    // Module count badge
    this.moduleCountTarget.textContent = selectedModules.length

    // Implementation fee (sum of selected module costs)
    const implFee = this.moduleCheckboxTargets
      .filter(cb => cb.checked)
      .reduce((sum, cb) => sum + parseInt(cb.dataset.moduleCost || 0), 0)

    // Hosting cost
    const deployType = this.deployRadioTargets.find(r => r.checked)?.dataset?.deployKey || "online"
    let hostingCost = 0
    if (deployType !== "online") {
      const selectedTier = this.tierRadioTargets.find(r => r.checked)
      if (selectedTier) {
        // Read cost from data attribute on the radio input
        hostingCost = parseInt(selectedTier.dataset.tierCost || 0)
      }
    }

    const total = implFee + hostingCost

    // Update display
    this.implFeeTarget.textContent = `PKR ${this.formatNumber(implFee)}`
    this.hostingCostTarget.textContent = `PKR ${this.formatNumber(hostingCost)}`
    this.totalCostTarget.textContent = this.formatNumber(total)

    // Animate total if changed
    this.totalCostTarget.classList.add("scale-110")
    setTimeout(() => this.totalCostTarget.classList.remove("scale-110"), 200)

    // Update button state
    this.submitBtnTarget.disabled = selectedModules.length === 0
    if (selectedModules.length === 0) {
      this.submitBtnTarget.classList.add("opacity-50", "cursor-not-allowed")
      this.submitBtnTarget.classList.remove("cursor-pointer")
    } else {
      this.submitBtnTarget.classList.remove("opacity-50", "cursor-not-allowed")
      this.submitBtnTarget.classList.add("cursor-pointer")
    }
  }

  highlightSelectedModules() {
    this.moduleCheckboxTargets.forEach(cb => {
      const card = cb.closest(".module-card")
      if (card && cb.checked) {
        card.classList.add("selected")
      }
    })
  }

  formatNumber(n) {
    return n.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",")
  }
}
