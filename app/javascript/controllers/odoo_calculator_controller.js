import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "moduleCheckbox", "moduleCount",
    "implFee",
    "subYearly", "subMonthly", "subPerUserLabel", "subPlanLabel",
    "hostingCost", "hostingRow", "hostingRowLabel",
    "recurringMonthly", "recurringYearly",
    "year1Total",
    "deployRadio", "deployLabel",
    "tierRadio", "tierLabel", "hostingSection",
    "shTierRadio", "shTierLabel", "shSection",
    "numUsers",
    "customerSelect", "customerName",
    "submitBtn"
  ]

  static values = {
    subData:    String,
    tierData:   String,
    shTierData: String
  }

  connect() {
    this.subData    = JSON.parse(this.subDataValue    || "{}")
    this.tierData   = JSON.parse(this.tierDataValue   || "{}")
    this.shTierData = JSON.parse(this.shTierDataValue || "{}")
    this.highlightSelectedModules()
    this.updateDeploymentUI()
    this.recalculate()
  }

  // ── Actions ───────────────────────────────────────────────────────────────

  toggleModule(event) {
    const card     = event.currentTarget
    const checkbox = card.querySelector('input[type="checkbox"]')
    if (event.target !== checkbox) checkbox.checked = !checkbox.checked
    card.classList.toggle("selected", checkbox.checked)
    this.recalculate()
  }

  customerChanged(event) {
    const hasCustomer = !!event.target.value
    this.customerNameTarget.disabled = hasCustomer
    this.customerNameTarget.classList.toggle("opacity-50", hasCustomer)
    if (hasCustomer) this.customerNameTarget.value = ""
  }

  deploymentChanged() {
    this.updateDeploymentUI()
    this.recalculate()
  }

  tierChanged() {
    this.updateTierUI()
    this.recalculate()
  }

  shTierChanged() {
    this.updateSHTierUI()
    this.recalculate()
  }

  usersChanged()    { this.recalculate() }
  incrementUsers()  { this.numUsersTarget.value = Math.min(500, this.users() + 1); this.recalculate() }
  decrementUsers()  { this.numUsersTarget.value = Math.max(1,   this.users() - 1); this.recalculate() }

  // ── Core calculation ──────────────────────────────────────────────────────

  recalculate() {
    const deployType  = this.currentDeployType()
    const users       = this.users()
    const sub         = this.subData[deployType] || this.subData["online"] || {}
    const tierKey     = this.currentTierKey()
    const shTierKey   = this.currentSHTierKey()
    const tier        = this.tierData[tierKey]     || {}
    const shTier      = this.shTierData[shTierKey] || {}

    // One-time
    const implFee = this.selectedModuleCosts()

    // Subscription
    const subMonthlyPerUser = sub.pkr_monthly || 0
    const subMonthlyTotal   = subMonthlyPerUser * users
    const subYearly         = subMonthlyTotal * 12

    // Hosting
    const needsServer  = deployType === "on_premise"
    const needsSH      = deployType === "sh"
    const hostingMonthly = needsServer ? (tier.monthly    || 0)
                         : needsSH     ? (shTier.monthly  || 0) : 0
    const hostingYearly  = needsServer ? (tier.annual     || 0)
                         : needsSH     ? (shTier.annual   || 0) : 0

    // Recurring
    const recurMonthly = subMonthlyTotal + hostingMonthly
    const recurYearly  = subYearly + hostingYearly

    // Year 1
    const year1 = implFee + subYearly + hostingYearly

    // ── Update DOM ────────────────────────────────────────────────────────
    this.moduleCountTarget.textContent = this.selectedModuleKeys().length

    this.implFeeTarget.textContent         = "PKR " + this.fmt(implFee)
    this.subYearlyTarget.textContent       = "PKR " + this.fmt(subYearly)
    this.subMonthlyTarget.textContent      = "PKR " + this.fmt(subMonthlyTotal) + "/mo"
    this.subPerUserLabelTarget.textContent = `PKR ${this.fmt(subMonthlyPerUser)} × ${users} users / mo`
    this.subPlanLabelTarget.textContent    = sub.plan || "Standard"

    this.hostingCostTarget.textContent  = "PKR " + this.fmt(hostingYearly)
    this.hostingRowTarget.style.display = (deployType === "online") ? "none" : "flex"
    if (this.hasHostingRowLabelTarget) {
      this.hostingRowLabelTarget.textContent = needsSH ? "Odoo.sh Platform / yr" : "Server Hosting / yr"
    }

    this.recurringMonthlyTarget.textContent = "PKR " + this.fmt(recurMonthly)
    this.recurringYearlyTarget.textContent  = "PKR " + this.fmt(recurYearly)

    // Year 1 hero
    this.year1TotalTarget.textContent = "PKR " + this.fmt(year1)

    // Animate
    this.year1TotalTarget.style.transition = "transform 0.15s"
    this.year1TotalTarget.style.transform  = "scale(1.05)"
    setTimeout(() => { this.year1TotalTarget.style.transform = "scale(1)" }, 150)

    // Submit button state
    const hasModules = this.selectedModuleKeys().length > 0
    this.submitBtnTarget.disabled = !hasModules
    this.submitBtnTarget.classList.toggle("opacity-50",         !hasModules)
    this.submitBtnTarget.classList.toggle("cursor-not-allowed", !hasModules)
    this.submitBtnTarget.classList.toggle("cursor-pointer",     hasModules)
  }

  // ── UI helpers ────────────────────────────────────────────────────────────

  updateDeploymentUI() {
    const deployType = this.currentDeployType()
    this.deployLabelTargets.forEach(label => {
      const sel = label.dataset.deployKey === deployType
      label.classList.toggle("border-red-500",  sel)
      label.classList.toggle("bg-red-50",       sel)
      label.classList.toggle("border-gray-100", !sel)
    })
    this.hostingSectionTarget.style.display = deployType === "on_premise" ? "block" : "none"
    this.shSectionTarget.style.display      = deployType === "sh"         ? "block" : "none"
  }

  updateTierUI() {
    const tierKey = this.currentTierKey()
    this.tierLabelTargets.forEach(label => {
      const sel = label.dataset.tierKey === tierKey
      label.classList.toggle("border-red-500",  sel)
      label.classList.toggle("bg-red-50",       sel)
      label.classList.toggle("border-gray-100", !sel)
    })
  }

  updateSHTierUI() {
    const shTierKey = this.currentSHTierKey()
    this.shTierLabelTargets.forEach(label => {
      const sel = label.dataset.tierKey === shTierKey
      label.classList.toggle("border-red-500",  sel)
      label.classList.toggle("bg-red-50",       sel)
      label.classList.toggle("border-gray-100", !sel)
    })
  }

  highlightSelectedModules() {
    this.moduleCheckboxTargets.forEach(cb => {
      cb.closest(".module-card")?.classList.toggle("selected", cb.checked)
    })
  }

  // ── Accessors ─────────────────────────────────────────────────────────────

  currentDeployType() {
    return this.deployRadioTargets.find(r => r.checked)?.dataset?.deployKey || "online"
  }

  currentTierKey() {
    return this.tierRadioTargets.find(r => r.checked)?.dataset?.tierKey || ""
  }

  currentSHTierKey() {
    return this.shTierRadioTargets.find(r => r.checked)?.dataset?.tierKey || ""
  }

  users() {
    return Math.max(1, parseInt(this.numUsersTarget.value) || 1)
  }

  selectedModuleKeys() {
    return this.moduleCheckboxTargets.filter(cb => cb.checked).map(cb => cb.dataset.moduleKey)
  }

  selectedModuleCosts() {
    return this.moduleCheckboxTargets
      .filter(cb => cb.checked)
      .reduce((sum, cb) => sum + parseInt(cb.dataset.moduleCost || 0), 0)
  }

  fmt(n) {
    return Math.round(n).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",")
  }
}
