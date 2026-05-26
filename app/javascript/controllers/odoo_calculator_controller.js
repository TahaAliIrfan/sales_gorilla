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
    "submitBtn",
    // Custom modules
    "customModulesList", "customModulesEmpty", "customModuleRow", "customModuleCost", "customModuleTemplate",
    // Smart Detect
    "analyzeBtn", "analyzeLabel", "analyzeText", "analyzeFile", "analyzeFileName", "analyzeStatus",
    // Business context (set by Smart Detect)
    "industrySelect", "sizeSelect", "painPointCheckbox"
  ]

  static values = {
    subData:     String,
    tierData:    String,
    shTierData:  String,
    analyzeUrl:  String
  }

  connect() {
    this.subData    = JSON.parse(this.subDataValue    || "{}")
    this.tierData   = JSON.parse(this.tierDataValue   || "{}")
    this.shTierData = JSON.parse(this.shTierDataValue || "{}")
    this.highlightSelectedModules()
    this.updateDeploymentUI()
    this.recalculate()
    this.refreshCustomModulesEmpty()
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

  // ── Custom modules ────────────────────────────────────────────────────────

  addCustomModule(event) {
    event?.preventDefault()
    this.appendCustomModuleRow({ label: "", description: "", impl_cost: "" })
    this.refreshCustomModulesEmpty()
    this.recalculate()
  }

  removeCustomModule(event) {
    event.preventDefault()
    const row = event.currentTarget.closest(".custom-module-row")
    row?.remove()
    this.refreshCustomModulesEmpty()
    this.recalculate()
  }

  appendCustomModuleRow({ label, description, impl_cost }) {
    if (!this.hasCustomModuleTemplateTarget || !this.hasCustomModulesListTarget) return

    const fragment = this.customModuleTemplateTarget.content.cloneNode(true)
    const inputs = fragment.querySelectorAll("input")
    inputs.forEach(input => {
      if (input.name.endsWith("[label]"))       input.value = label || ""
      if (input.name.endsWith("[description]")) input.value = description || ""
      if (input.name.endsWith("[impl_cost]"))   input.value = impl_cost ?? ""
    })
    this.customModulesListTarget.appendChild(fragment)
  }

  refreshCustomModulesEmpty() {
    if (!this.hasCustomModulesEmptyTarget) return
    const hasRows = this.customModuleRows().length > 0
    this.customModulesEmptyTarget.style.display = hasRows ? "none" : ""
  }

  customModuleRows() {
    if (!this.hasCustomModulesListTarget) return []
    return Array.from(this.customModulesListTarget.querySelectorAll(".custom-module-row"))
  }

  customModulesCost() {
    return this.customModuleRows().reduce((sum, row) => {
      const costInput = row.querySelector(".custom-module-cost")
      const labelInput = row.querySelector('input[name$="[label]"]')
      if (!labelInput || !labelInput.value.trim()) return sum
      return sum + (parseInt(costInput?.value || 0) || 0)
    }, 0)
  }

  customModulesCount() {
    return this.customModuleRows().filter(row => {
      const labelInput = row.querySelector('input[name$="[label]"]')
      return labelInput && labelInput.value.trim()
    }).length
  }

  // ── Smart Detect ──────────────────────────────────────────────────────────

  analyzeFilePicked(event) {
    const file = event.target.files?.[0]
    if (!this.hasAnalyzeFileNameTarget) return
    this.analyzeFileNameTarget.textContent = file ? file.name : "Choose file"
  }

  async runAnalyze(event) {
    event?.preventDefault()
    const text = this.hasAnalyzeTextTarget ? this.analyzeTextTarget.value.trim() : ""
    const file = this.hasAnalyzeFileTarget ? this.analyzeFileTarget.files?.[0]   : null

    if (!text && !file) {
      this.showStatus("Paste text or upload a file first.", "error")
      return
    }

    const url = this.analyzeUrlValue
    if (!url) {
      this.showStatus("Analyze endpoint not configured.", "error")
      return
    }

    this.setAnalyzing(true)
    this.showStatus("Analyzing with Claude — this can take 10–30 seconds…", "info")

    const formData = new FormData()
    if (text)  formData.append("text", text)
    if (file)  formData.append("file", file)

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    try {
      const response = await fetch(url, {
        method: "POST",
        headers: csrfToken ? { "X-CSRF-Token": csrfToken, "Accept": "application/json" } : { "Accept": "application/json" },
        body: formData,
        credentials: "same-origin"
      })

      const data = await response.json().catch(() => null)

      if (!response.ok) {
        this.showStatus(data?.error || `Analysis failed (${response.status}).`, "error")
      } else {
        this.applyAnalysis(data || {})
      }
    } catch (err) {
      this.showStatus(`Network error: ${err.message}`, "error")
    } finally {
      this.setAnalyzing(false)
    }
  }

  applyAnalysis(data) {
    // 1. Toggle standard module checkboxes
    const detected = new Set(Array.isArray(data.modules) ? data.modules : [])
    let modulesChecked = 0
    this.moduleCheckboxTargets.forEach(cb => {
      const wantChecked = detected.has(cb.dataset.moduleKey)
      if (wantChecked && !cb.checked) modulesChecked++
      cb.checked = wantChecked
      cb.closest(".module-card")?.classList.toggle("selected", wantChecked)
    })

    // 2. Append custom modules
    const customs = Array.isArray(data.custom_modules) ? data.custom_modules : []
    // Clear existing AI-suggested rows? No — append. User may want to keep manual entries.
    customs.forEach(cm => this.appendCustomModuleRow(cm))

    // 3. Fill industry / company size
    if (data.industry && this.hasIndustrySelectTarget) {
      const opt = Array.from(this.industrySelectTarget.options).find(o => o.value === data.industry)
      if (opt) this.industrySelectTarget.value = data.industry
    }
    if (data.company_size && this.hasSizeSelectTarget) {
      const opt = Array.from(this.sizeSelectTarget.options).find(o => o.value === data.company_size)
      if (opt) this.sizeSelectTarget.value = data.company_size
    }

    // 4. Check pain points
    const pains = new Set(Array.isArray(data.pain_points) ? data.pain_points : [])
    if (this.hasPainPointCheckboxTarget) {
      this.painPointCheckboxTargets.forEach(cb => {
        if (pains.has(cb.dataset.pain)) cb.checked = true
      })
    }

    // 5. Recalculate + status
    this.refreshCustomModulesEmpty()
    this.recalculate()

    const parts = []
    parts.push(`${modulesChecked} standard module${modulesChecked === 1 ? '' : 's'}`)
    parts.push(`${customs.length} custom module${customs.length === 1 ? '' : 's'}`)
    if (data.industry)     parts.push(`industry: ${data.industry}`)
    if (data.company_size) parts.push(`size: ${data.company_size}`)
    if (pains.size > 0)    parts.push(`${pains.size} pain point${pains.size === 1 ? '' : 's'}`)
    this.showStatus(`Detected — ${parts.join(' · ')}. Review and adjust below.`, "success")
  }

  setAnalyzing(on) {
    if (!this.hasAnalyzeBtnTarget) return
    this.analyzeBtnTarget.disabled = on
    if (this.hasAnalyzeLabelTarget) this.analyzeLabelTarget.textContent = on ? "Analyzing…" : "Analyze"
  }

  showStatus(message, kind) {
    if (!this.hasAnalyzeStatusTarget) return
    const colors = {
      info:    "bg-purple-50 text-purple-700 border border-purple-100",
      success: "bg-green-50 text-green-700 border border-green-100",
      error:   "bg-red-50 text-red-700 border border-red-100"
    }
    this.analyzeStatusTarget.className = `mx-4 mb-4 px-3 py-2 rounded-lg text-xs font-medium ${colors[kind] || colors.info}`
    this.analyzeStatusTarget.textContent = message
    this.analyzeStatusTarget.classList.remove("hidden")
  }

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
    const implFee = this.selectedModuleCosts() + this.customModulesCost()

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
    const totalModules = this.selectedModuleKeys().length + this.customModulesCount()
    this.moduleCountTarget.textContent = totalModules

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
    const hasSomething = totalModules > 0
    this.submitBtnTarget.disabled = !hasSomething
    this.submitBtnTarget.classList.toggle("opacity-50",         !hasSomething)
    this.submitBtnTarget.classList.toggle("cursor-not-allowed", !hasSomething)
    this.submitBtnTarget.classList.toggle("cursor-pointer",     hasSomething)
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
