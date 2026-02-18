import { Controller } from "https://cdn.jsdelivr.net/npm/@hotwired/stimulus@3.2.2/dist/stimulus.js"

export default class extends Controller {
  static values = { pageId: Number }

  connect() {
    this.scale = 1.0
    this.panX = 0
    this.panY = 0
    this.isPanning = false
    this.isDragging = false
    this.dragTarget = null
    this.startX = 0
    this.startY = 0
    this.startElX = 0
    this.startElY = 0
    this.scrollLock = false

    this.world = this.element.querySelector(".canvas-world")
    if (!this.world) return

    // Bind events
    this.onMouseDown = this.onMouseDown.bind(this)
    this.onMouseMove = this.onMouseMove.bind(this)
    this.onMouseUp = this.onMouseUp.bind(this)
    this.onWheel = this.onWheel.bind(this)

    this.element.addEventListener("mousedown", this.onMouseDown)
    document.addEventListener("mousemove", this.onMouseMove)
    document.addEventListener("mouseup", this.onMouseUp)
    this.element.addEventListener("wheel", this.onWheel, { passive: false })

    // Touch events
    this.onTouchStart = this.onTouchStart.bind(this)
    this.onTouchMove = this.onTouchMove.bind(this)
    this.onTouchEnd = this.onTouchEnd.bind(this)
    this.element.addEventListener("touchstart", this.onTouchStart, { passive: false })
    document.addEventListener("touchmove", this.onTouchMove, { passive: false })
    document.addEventListener("touchend", this.onTouchEnd)

    // Context menu
    this.onContextMenu = this.onContextMenu.bind(this)
    this.onDocumentClick = this.onDocumentClick.bind(this)
    this.onKeyDown = this.onKeyDown.bind(this)
    this.element.addEventListener("contextmenu", this.onContextMenu)
    document.addEventListener("click", this.onDocumentClick)
    document.addEventListener("keydown", this.onKeyDown)
    this.menu = document.getElementById("canvas-context-menu")
    this.menuItems = document.getElementById("canvas-context-menu-items")

    // Configurable menu item registries
    this.canvasMenuItems = [
      { label: "Add Note", icon: "\ud83d\udcdd", action: (wx, wy) => this.addNote(wx, wy) },
      { label: "Add Weather Widget", icon: "\u2600\ufe0f", action: (wx, wy) => this.addWeatherWidget(wx, wy) },
      { separator: true },
      { label: () => this.scrollLock ? "Scroll Lock: On" : "Scroll Lock: Off", icon: "\ud83d\udd12", action: () => this.toggleScrollLock() },
      { label: "Reset View", icon: "\ud83d\udd04", action: () => this.resetView() },
    ]

    this.componentMenuItems = [
      { label: "Chat about this", icon: "\ud83d\udcac", action: (comp) => this.chatAboutComponent(comp) },
      { label: "Duplicate", icon: "\ud83d\udccb", action: (comp) => this.duplicateComponent(comp) },
      { separator: true },
      { label: "Delete", icon: "\ud83d\uddd1\ufe0f", destructive: true, action: (comp) => this.deleteComponent(comp) },
    ]

    // Expose for extensibility
    window.canvasController = this

    // MutationObserver for Turbo Stream updates
    this.observer = new MutationObserver((mutations) => {
      for (const mutation of mutations) {
        for (const node of mutation.addedNodes) {
          if (node.classList?.contains("canvas-component")) {
            this.initComponent(node)
          }
        }
      }
    })
    this.observer.observe(this.world, { childList: true })

    // Init existing components
    this.world.querySelectorAll(".canvas-component").forEach(c => this.initComponent(c))

    this.updateTransform()
    this.updateZoomIndicator()
  }

  disconnect() {
    this.element.removeEventListener("mousedown", this.onMouseDown)
    document.removeEventListener("mousemove", this.onMouseMove)
    document.removeEventListener("mouseup", this.onMouseUp)
    this.element.removeEventListener("wheel", this.onWheel)
    this.element.removeEventListener("touchstart", this.onTouchStart)
    document.removeEventListener("touchmove", this.onTouchMove)
    document.removeEventListener("touchend", this.onTouchEnd)
    this.element.removeEventListener("contextmenu", this.onContextMenu)
    document.removeEventListener("click", this.onDocumentClick)
    document.removeEventListener("keydown", this.onKeyDown)
    this.observer?.disconnect()
    if (window.canvasController === this) window.canvasController = null
  }

  initComponent(el) {
    el.style.zIndex = el.dataset.z || 0
  }

  // --- Context Menu ---

  onContextMenu(e) {
    e.preventDefault()
    const component = e.target.closest(".canvas-component")
    if (component) {
      this.showComponentMenu(e.clientX, e.clientY, component)
    } else {
      const rect = this.element.getBoundingClientRect()
      const worldX = (e.clientX - rect.left - this.panX) / this.scale
      const worldY = (e.clientY - rect.top - this.panY) / this.scale
      this.showCanvasMenu(e.clientX, e.clientY, worldX, worldY)
    }
  }

  showCanvasMenu(screenX, screenY, worldX, worldY) {
    this.menuItems.innerHTML = ""
    for (const item of this.canvasMenuItems) {
      if (item.separator) {
        this.menuItems.appendChild(Object.assign(document.createElement("div"), { className: "canvas-context-menu-separator" }))
      } else {
        const label = typeof item.label === "function" ? item.label() : item.label
        const btn = document.createElement("button")
        btn.className = "canvas-context-menu-item"
        btn.innerHTML = `<span>${item.icon}</span><span>${label}</span>`
        btn.addEventListener("click", () => { this.hideMenu(); item.action(worldX, worldY) })
        this.menuItems.appendChild(btn)
      }
    }
    this.positionAndShowMenu(screenX, screenY)
  }

  showComponentMenu(screenX, screenY, component) {
    this.menuItems.innerHTML = ""
    for (const item of this.componentMenuItems) {
      if (item.separator) {
        this.menuItems.appendChild(Object.assign(document.createElement("div"), { className: "canvas-context-menu-separator" }))
      } else {
        const btn = document.createElement("button")
        btn.className = "canvas-context-menu-item" + (item.destructive ? " destructive" : "")
        btn.innerHTML = `<span>${item.icon}</span><span>${item.label}</span>`
        btn.addEventListener("click", () => { this.hideMenu(); item.action(component) })
        this.menuItems.appendChild(btn)
      }
    }
    this.positionAndShowMenu(screenX, screenY)
  }

  positionAndShowMenu(x, y) {
    this.menu.style.display = "block"
    // Avoid viewport overflow
    const menuRect = this.menu.getBoundingClientRect()
    if (x + menuRect.width > window.innerWidth) x = window.innerWidth - menuRect.width - 8
    if (y + menuRect.height > window.innerHeight) y = window.innerHeight - menuRect.height - 8
    this.menu.style.left = x + "px"
    this.menu.style.top = y + "px"
  }

  hideMenu() {
    if (this.menu) this.menu.style.display = "none"
  }

  onDocumentClick(e) {
    if (this.menu && !this.menu.contains(e.target)) this.hideMenu()
  }

  onKeyDown(e) {
    if (e.key === "Escape") this.hideMenu()
  }

  // --- Context Menu Actions ---

  async createComponent(attrs) {
    const pageId = this.pageIdValue
    if (!pageId) return null
    try {
      const resp = await fetch(`/api/pages/${pageId}/components`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(attrs)
      })
      return await resp.json()
    } catch (e) {
      console.error("[Canvas] Failed to create component:", e)
      return null
    }
  }

  addNote(x, y) {
    this.createComponent({
      component_type: "card",
      content: '<p style="color:var(--muted-foreground);margin:0">Double-click to edit...</p>',
      x, y, width: 240
    })
  }

  addWeatherWidget(x, y) {
    this.createComponent({
      component_type: "weather",
      content: this.weatherWidgetHtml(),
      x, y, width: 280
    })
  }

  weatherWidgetHtml() {
    return `<div class="flex flex-col gap-2">
  <div class="flex items-center justify-between">
    <div>
      <div class="font-semibold text-sm" style="color:var(--foreground)">Curitiba, BR</div>
      <div class="text-xs" style="color:var(--muted-foreground)">Partly cloudy</div>
    </div>
    <span class="text-2xl">\u2600\ufe0f</span>
  </div>
  <div class="flex items-baseline gap-1">
    <span class="text-3xl font-bold" style="color:var(--foreground)">22\u00b0C</span>
    <span class="text-xs" style="color:var(--muted-foreground)">Feels like 21\u00b0</span>
  </div>
  <div class="grid grid-cols-3 gap-2 pt-1" style="border-top:1px solid var(--border)">
    <div class="text-center">
      <div class="text-xs" style="color:var(--muted-foreground)">Humidity</div>
      <div class="text-sm font-medium" style="color:var(--foreground)">68%</div>
    </div>
    <div class="text-center">
      <div class="text-xs" style="color:var(--muted-foreground)">Wind</div>
      <div class="text-sm font-medium" style="color:var(--foreground)">12 km/h</div>
    </div>
    <div class="text-center">
      <div class="text-xs" style="color:var(--muted-foreground)">UV Index</div>
      <div class="text-sm font-medium" style="color:var(--foreground)">4</div>
    </div>
  </div>
</div>`
  }

  async chatAboutComponent(comp) {
    const compId = comp.dataset.componentId
    const content = comp.querySelector(".canvas-component-content")?.textContent?.trim() || ""
    const preview = content.substring(0, 120)
    const pageId = this.pageIdValue
    const footer = window.chatFooter

    if (!footer || !pageId) return

    // Highlight the component on the canvas
    comp.classList.add("canvas-component-highlight")
    setTimeout(() => comp.classList.remove("canvas-component-highlight"), 2000)

    // Derive a title from the component content
    const firstLine = content.split("\n").find(l => l.trim()) || ""
    const title = firstLine.substring(0, 50) || `Widget #${compId}`

    // Create a new conversation in this canvas with the widget title
    try {
      const resp = await fetch("/api/conversations", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: `ai_page_id=${pageId}&title=${encodeURIComponent(title)}`
      })
      const data = await resp.json()

      // Ensure the canvas is open, then open the new conversation
      const canvas = footer.canvases.find(c => c.pageId === pageId)
      if (canvas) {
        footer.openConversation(data.id, data.title, data.slug, pageId)
      } else {
        footer.openCanvas(pageId, title, "", data.id, data.title, data.slug)
      }

      // Prefill the textarea with a reference to the component
      const prefill = `[Re: canvas widget #${compId}]\n"${preview}"\n\n`
      const tryPrefill = (attempts) => {
        const panel = document.querySelector(".chat-panel.active")
        const textarea = panel?.querySelector("textarea")
        if (textarea) {
          textarea.value = prefill
          textarea.focus()
          textarea.setSelectionRange(prefill.length, prefill.length)
        } else if (attempts > 0) {
          setTimeout(() => tryPrefill(attempts - 1), 200)
        }
      }
      tryPrefill(5)
    } catch (e) {
      console.error("[Canvas] Failed to create conversation for component:", e)
    }
  }

  async duplicateComponent(comp) {
    const compId = comp.dataset.componentId
    const pageId = this.pageIdValue
    if (!compId || !pageId) return

    try {
      const resp = await fetch(`/api/pages/${pageId}/components/${compId}`)
      const data = await resp.json()
      this.createComponent({
        component_type: data.component_type,
        content: data.content,
        x: (data.x || 0) + 24,
        y: (data.y || 0) + 24,
        width: data.width,
        height: data.height,
        z_index: data.z_index
      })
    } catch (e) {
      console.error("[Canvas] Failed to duplicate component:", e)
    }
  }

  async deleteComponent(comp) {
    const compId = comp.dataset.componentId
    const pageId = this.pageIdValue
    if (!compId || !pageId) return

    // Optimistic DOM removal
    comp.remove()

    try {
      await fetch(`/api/pages/${pageId}/components/${compId}`, { method: "DELETE" })
    } catch (e) {
      console.error("[Canvas] Failed to delete component:", e)
    }
  }

  toggleScrollLock() {
    this.scrollLock = !this.scrollLock
    this.updateScrollLockIndicator()
  }

  updateScrollLockIndicator() {
    const indicator = this.element.querySelector(".canvas-zoom-indicator")
    if (indicator) {
      const zoom = Math.round(this.scale * 100) + "%"
      indicator.textContent = this.scrollLock ? `${zoom} \ud83d\udd12` : zoom
    }
  }

  resetView() {
    this.scale = 1.0
    this.panX = 0
    this.panY = 0
    this.updateTransform()
    this.updateZoomIndicator()
  }

  // --- Pan & Drag (Mouse) ---

  onMouseDown(e) {
    if (e.button !== 0) return // Only primary (left) button
    const component = e.target.closest(".canvas-component")
    if (component) {
      // Start dragging component
      this.isDragging = true
      this.dragTarget = component
      this.startX = e.clientX
      this.startY = e.clientY
      this.startElX = parseFloat(component.style.left) || 0
      this.startElY = parseFloat(component.style.top) || 0
      component.classList.add("dragging")
      e.preventDefault()
    } else if (e.target === this.element || e.target === this.world || e.target.classList.contains("canvas-dot-grid")) {
      // Start panning
      this.isPanning = true
      this.startX = e.clientX
      this.startY = e.clientY
      this.startPanX = this.panX
      this.startPanY = this.panY
      this.element.style.cursor = "grabbing"
      e.preventDefault()
    }
  }

  onMouseMove(e) {
    if (this.isPanning) {
      this.panX = this.startPanX + (e.clientX - this.startX)
      this.panY = this.startPanY + (e.clientY - this.startY)
      this.updateTransform()
    } else if (this.isDragging && this.dragTarget) {
      const dx = (e.clientX - this.startX) / this.scale
      const dy = (e.clientY - this.startY) / this.scale
      this.dragTarget.style.left = (this.startElX + dx) + "px"
      this.dragTarget.style.top = (this.startElY + dy) + "px"
    }
  }

  onMouseUp(e) {
    if (this.isPanning) {
      this.isPanning = false
      this.element.style.cursor = ""
    }
    if (this.isDragging && this.dragTarget) {
      this.dragTarget.classList.remove("dragging")
      this.saveComponentPosition(this.dragTarget)
      this.isDragging = false
      this.dragTarget = null
    }
  }

  // --- Touch ---

  onTouchStart(e) {
    if (e.touches.length !== 1) return
    const touch = e.touches[0]
    const component = touch.target.closest(".canvas-component")
    if (component) {
      this.isDragging = true
      this.dragTarget = component
      this.startX = touch.clientX
      this.startY = touch.clientY
      this.startElX = parseFloat(component.style.left) || 0
      this.startElY = parseFloat(component.style.top) || 0
      component.classList.add("dragging")
      e.preventDefault()
    } else {
      this.isPanning = true
      this.startX = touch.clientX
      this.startY = touch.clientY
      this.startPanX = this.panX
      this.startPanY = this.panY
      e.preventDefault()
    }
  }

  onTouchMove(e) {
    if (e.touches.length !== 1) return
    const touch = e.touches[0]
    if (this.isPanning) {
      this.panX = this.startPanX + (touch.clientX - this.startX)
      this.panY = this.startPanY + (touch.clientY - this.startY)
      this.updateTransform()
    } else if (this.isDragging && this.dragTarget) {
      const dx = (touch.clientX - this.startX) / this.scale
      const dy = (touch.clientY - this.startY) / this.scale
      this.dragTarget.style.left = (this.startElX + dx) + "px"
      this.dragTarget.style.top = (this.startElY + dy) + "px"
      e.preventDefault()
    }
  }

  onTouchEnd() {
    if (this.isPanning) this.isPanning = false
    if (this.isDragging && this.dragTarget) {
      this.dragTarget.classList.remove("dragging")
      this.saveComponentPosition(this.dragTarget)
      this.isDragging = false
      this.dragTarget = null
    }
  }

  // --- Zoom ---

  onWheel(e) {
    e.preventDefault()

    if (this.scrollLock) {
      // Scroll lock: wheel pans the canvas instead of zooming
      this.panX -= e.deltaX || 0
      this.panY -= e.deltaY || 0
      this.updateTransform()
      return
    }

    const delta = e.deltaY > 0 ? -0.08 : 0.08
    const newScale = Math.min(Math.max(this.scale + delta, 0.1), 3.0)

    // Zoom toward cursor
    const rect = this.element.getBoundingClientRect()
    const cx = e.clientX - rect.left
    const cy = e.clientY - rect.top

    const ratio = newScale / this.scale
    this.panX = cx - ratio * (cx - this.panX)
    this.panY = cy - ratio * (cy - this.panY)
    this.scale = newScale

    this.updateTransform()
    this.updateZoomIndicator()
  }

  updateTransform() {
    if (this.world) {
      this.world.style.transform = `translate(${this.panX}px, ${this.panY}px) scale(${this.scale})`
    }
  }

  updateZoomIndicator() {
    const indicator = this.element.querySelector(".canvas-zoom-indicator")
    if (indicator) {
      const zoom = Math.round(this.scale * 100) + "%"
      indicator.textContent = this.scrollLock ? `${zoom} \ud83d\udd12` : zoom
    }
  }

  // --- Persist position ---

  async saveComponentPosition(el) {
    const componentId = el.dataset.componentId
    const pageId = this.pageIdValue
    if (!componentId || !pageId) return

    const x = parseFloat(el.style.left) || 0
    const y = parseFloat(el.style.top) || 0

    try {
      await fetch(`/api/pages/${pageId}/components/${componentId}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: `x=${x}&y=${y}`
      })
    } catch (e) {
      console.error("[Canvas] Failed to save position:", e)
    }
  }
}
