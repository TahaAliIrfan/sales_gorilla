import { Controller } from "@hotwired/stimulus"

// Drives the campaign template picker: when an approved WhatsApp template is
// chosen, show a body preview and render one input per template variable. The
// saved values (edit) are prefilled, and values already typed are preserved
// when switching templates.
export default class extends Controller {
  static targets = ["select", "catalog", "preview", "variables"]
  static values = { values: Object }

  connect() {
    try {
      this.catalog = JSON.parse(this.catalogTarget.textContent || "[]")
    } catch (_e) {
      this.catalog = []
    }
    this.render()
  }

  select() {
    this.render()
  }

  render() {
    const template = this.catalog.find((t) => t.content_sid === this.selectTarget.value)

    if (!template) {
      this.previewTarget.classList.add("hidden")
      this.previewTarget.textContent = ""
      this.variablesTarget.innerHTML = ""
      return
    }

    this.previewTarget.textContent = template.body || "(no preview available)"
    this.previewTarget.classList.remove("hidden")

    const current = this.collectValues()
    this.variablesTarget.innerHTML = ""

    const keys = template.variable_keys || []
    for (const key of keys) {
      const saved = current[key] ?? this.valuesValue?.[key] ?? ""
      this.variablesTarget.appendChild(this.variableRow(key, saved))
    }
  }

  // Preserve anything already typed before we re-render the inputs.
  collectValues() {
    const map = {}
    this.variablesTarget.querySelectorAll("input[data-var-key]").forEach((input) => {
      map[input.dataset.varKey] = input.value
    })
    return map
  }

  variableRow(key, value) {
    const wrap = document.createElement("div")

    const label = document.createElement("label")
    label.className = "block text-xs font-medium text-gray-600 mb-1"
    label.textContent = `Variable {{${key}}}`
    wrap.appendChild(label)

    const input = document.createElement("input")
    input.type = "text"
    input.name = `campaign[content_variables][${key}]`
    input.value = value
    input.setAttribute("data-var-key", key)
    input.className = "block w-full rounded-md border-gray-300 shadow-sm text-sm focus:border-emerald-500 focus:ring-emerald-500"
    input.placeholder = "Fixed text or a token like {{customer_name}}"
    wrap.appendChild(input)

    return wrap
  }
}
