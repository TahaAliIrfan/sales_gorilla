// app/javascript/controllers/relay/user_admin_controller.js
// Drives inline role changes and activate/deactivate on the Settings → Team tab.
// POSTs to the existing UsersController JSON endpoints (#update_role /
// #toggle_active), keeping the same contract as the legacy users/index page,
// then reloads on success.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  changeRole(event) {
    const select = event.currentTarget
    const id = event.params.id
    const newRole = select.value
    const current = select.dataset.current

    if (newRole === current) return
    if (!window.confirm(`Change this user's role to ${newRole}?`)) {
      select.value = current
      return
    }

    this.#post(`/users/${id}/update_role`, { role_key: newRole })
      .then((data) => {
        if (data && data.success) {
          window.location.reload()
        } else {
          select.value = current
          window.alert((data && data.message) || "Failed to update role")
        }
      })
      .catch(() => {
        select.value = current
        window.alert("An error occurred")
      })
  }

  toggleActive(event) {
    const button = event.currentTarget
    const id = event.params.id
    const isActive = button.dataset.active === "true"
    const verb = isActive ? "deactivate" : "activate"

    if (!window.confirm(`Are you sure you want to ${verb} this user?`)) return
    button.disabled = true

    this.#post(`/users/${id}/toggle_active`, {})
      .then((data) => {
        if (data && data.success) {
          window.location.reload()
        } else {
          button.disabled = false
          window.alert((data && data.message) || "Failed to update status")
        }
      })
      .catch(() => {
        button.disabled = false
        window.alert("An error occurred")
      })
  }

  removeMember(event) {
    const button = event.currentTarget
    const id = event.params.id
    const name = button.dataset.name || "this user"

    if (!window.confirm(`Remove ${name} from the organization? They'll lose access immediately.`)) return
    button.disabled = true

    this.#request("DELETE", `/users/${id}/remove_member`, {})
      .then((data) => {
        if (data && data.success) {
          window.location.reload()
        } else {
          button.disabled = false
          window.alert((data && data.message) || "Failed to remove user")
        }
      })
      .catch(() => {
        button.disabled = false
        window.alert("An error occurred")
      })
  }

  #post(url, body) {
    return this.#request("POST", url, body)
  }

  #request(method, url, body) {
    return fetch(url, {
      method,
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify(body)
    }).then((response) => response.json())
  }
}
