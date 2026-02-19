import { Controller } from "https://cdn.jsdelivr.net/npm/@hotwired/stimulus@3.2.2/dist/stimulus.js"

export default class extends Controller {
  static targets = ["dropdown", "list", "loadMore"]

  connect() {
    this.page = 1
    this.limit = 5
    this.open = false
    this.loaded = false

    // SSE for real-time notifications
    this.source = new EventSource('/notifications/stream')
    this.source.onmessage = (event) => {
      window.Turbo.renderStreamMessage(event.data)
      // If dropdown is open, refresh the list
      if (this.open) {
        this.page = 1
        this._fetchNotifications(false)
      }
    }

    // Close on outside click
    this._outsideClick = (e) => {
      if (this.open && !this.element.contains(e.target)) {
        this._close()
      }
    }
    document.addEventListener('click', this._outsideClick)
  }

  disconnect() {
    this.source?.close()
    document.removeEventListener('click', this._outsideClick)
  }

  toggle(e) {
    e.stopPropagation()
    if (this.open) {
      this._close()
    } else {
      this._open()
    }
  }

  loadMore() {
    this._fetchNotifications(true)
  }

  _open() {
    this.open = true
    this.dropdownTarget.style.display = ""
    this.dropdownTarget.classList.add("open")
    const btn = this.element.querySelector("[data-action*='notifications#toggle']")
    if (btn) btn.setAttribute("aria-expanded", "true")
    if (!this.loaded) {
      this.page = 1
      this._fetchNotifications(false)
    }
  }

  _close() {
    this.open = false
    this.dropdownTarget.classList.remove("open")
    const btn = this.element.querySelector("[data-action*='notifications#toggle']")
    if (btn) btn.setAttribute("aria-expanded", "false")
    // Delay hiding to allow fade-out animation
    setTimeout(() => {
      if (!this.open) this.dropdownTarget.style.display = "none"
    }, 120)
  }

  async _fetchNotifications(append) {
    try {
      const resp = await fetch(`/api/notifications?page=${this.page}&limit=${this.limit}`)
      const data = await resp.json()

      if (append) {
        this.listTarget.insertAdjacentHTML("beforeend", data.html)
      } else {
        this.listTarget.innerHTML = data.html || '<div class="p-4 text-center text-fang-muted-fg text-xs">No notifications</div>'
      }

      this.loaded = true

      // Show/hide load more
      if (data.has_more) {
        this.page += 1
        this.loadMoreTarget.style.display = ""
      } else {
        this.loadMoreTarget.style.display = "none"
      }
    } catch (e) {
      console.error("[Notifications] Failed to fetch:", e)
      if (!append) {
        this.listTarget.innerHTML = '<div class="p-4 text-center text-fang-muted-fg text-xs">Failed to load</div>'
      }
    }
  }
}
