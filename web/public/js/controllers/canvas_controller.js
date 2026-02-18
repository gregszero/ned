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

    // Double-click to edit
    this.onDblClick = this.onDblClick.bind(this)
    this.element.addEventListener("dblclick", this.onDblClick)

    // Context menu
    this.onContextMenu = this.onContextMenu.bind(this)
    this.onDocumentClick = this.onDocumentClick.bind(this)
    this.onKeyDown = this.onKeyDown.bind(this)
    this.element.addEventListener("contextmenu", this.onContextMenu)
    document.addEventListener("click", this.onDocumentClick)
    document.addEventListener("keydown", this.onKeyDown)
    this.menu = document.getElementById("canvas-context-menu")
    this.menuItems = document.getElementById("canvas-context-menu-items")

    // Configurable menu item registries — built from widget types API
    this.canvasMenuItems = [
      { label: "Add Note", icon: "\ud83d\udcdd", action: (wx, wy) => this.addWidget('card', wx, wy) },
      { separator: true },
      { label: () => this.scrollLock ? "Scroll Lock: On" : "Scroll Lock: Off", icon: "\ud83d\udd12", action: () => this.toggleScrollLock() },
      { label: "Reset View", icon: "\ud83d\udd04", action: () => this.resetView() },
    ]

    // Fetch widget types and rebuild menu dynamically
    this._loadWidgetTypes()

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
        for (const node of mutation.removedNodes) {
          if (node.classList?.contains("canvas-component")) {
            this.destroyComponent(node)
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
    this.element.removeEventListener("dblclick", this.onDblClick)
    this.element.removeEventListener("contextmenu", this.onContextMenu)
    document.removeEventListener("click", this.onDocumentClick)
    document.removeEventListener("keydown", this.onKeyDown)
    this.observer?.disconnect()
    if (window.canvasController === this) window.canvasController = null
  }

  initComponent(el) {
    el.style.zIndex = el.dataset.z || 0
    const type = el.dataset.widgetType
    if (type && window.widgetBehaviors?.[type]?.init) {
      try {
        const meta = JSON.parse(el.dataset.widgetMetadata || '{}')
        window.widgetBehaviors[type].init(el, meta)
      } catch (e) {
        console.error(`[Canvas] Widget init failed for ${type}:`, e)
      }
    }
  }

  destroyComponent(el) {
    const type = el.dataset.widgetType
    if (type && window.widgetBehaviors?.[type]?.destroy) {
      try {
        window.widgetBehaviors[type].destroy(el)
      } catch (e) {
        console.error(`[Canvas] Widget destroy failed for ${type}:`, e)
      }
    }
  }

  // --- Double-click to Edit ---

  onDblClick(e) {
    const component = e.target.closest(".canvas-component")
    if (!component) return

    const contentEl = component.querySelector(".canvas-component-content")
    if (!contentEl || contentEl.isContentEditable) return

    // Enter edit mode
    this.editingComponent = component
    contentEl.contentEditable = "true"
    contentEl.style.cursor = "text"
    contentEl.style.userSelect = "text"
    component.style.cursor = "auto"
    contentEl.focus()

    // Select all text
    const range = document.createRange()
    range.selectNodeContents(contentEl)
    const sel = window.getSelection()
    sel.removeAllRanges()
    sel.addRange(range)

    // Save on blur
    const onBlur = () => {
      contentEl.removeEventListener("blur", onBlur)
      contentEl.removeEventListener("keydown", onKeyDown)
      this.finishEditing(component, contentEl)
    }

    // Escape cancels, Cmd/Ctrl+Enter confirms
    const onKeyDown = (ev) => {
      if (ev.key === "Escape") {
        ev.preventDefault()
        contentEl.removeEventListener("blur", onBlur)
        contentEl.removeEventListener("keydown", onKeyDown)
        this.finishEditing(component, contentEl)
      }
    }

    contentEl.addEventListener("blur", onBlur)
    contentEl.addEventListener("keydown", onKeyDown)

    e.preventDefault()
    e.stopPropagation()
  }

  finishEditing(component, contentEl) {
    contentEl.contentEditable = "false"
    contentEl.style.cursor = ""
    contentEl.style.userSelect = ""
    component.style.cursor = "grab"
    this.editingComponent = null

    // Persist updated content
    const compId = component.dataset.componentId
    const pageId = this.pageIdValue
    if (!compId || !pageId) return

    const newContent = contentEl.innerHTML
    fetch(`/api/pages/${pageId}/components/${compId}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: `content=${encodeURIComponent(newContent)}`
    }).catch(e => console.error("[Canvas] Failed to save content:", e))
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

  addWidget(type, x, y, metadata = {}) {
    const widgetType = this._widgetTypes?.find(w => w.type === type)
    const defaults = widgetType?.defaults || {}
    this.createComponent({
      component_type: type,
      x, y,
      width: type === 'card' ? 240 : 280,
      metadata: { ...defaults, ...metadata }
    })
  }

  async _loadWidgetTypes() {
    try {
      const resp = await fetch('/api/widget_types')
      const data = await resp.json()
      this._widgetTypes = data.widget_types || []

      // Rebuild canvas menu: widget items + separator + utility items
      const widgetItems = this._widgetTypes.map(w => ({
        label: w.label,
        icon: w.icon || "\ud83d\udccc",
        action: (wx, wy) => this.addWidget(w.type, wx, wy)
      }))

      const utilityItems = [
        { label: () => this.scrollLock ? "Scroll Lock: On" : "Scroll Lock: Off", icon: "\ud83d\udd12", action: () => this.toggleScrollLock() },
        { label: "Reset View", icon: "\ud83d\udd04", action: () => this.resetView() },
      ]

      this.canvasMenuItems = [...widgetItems, { separator: true }, ...utilityItems]
    } catch (e) {
      console.warn("[Canvas] Failed to load widget types, using defaults:", e)
    }
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
        component_type: data.type,
        content: data.content,
        x: (data.x || 0) + 24,
        y: (data.y || 0) + 24,
        width: data.width,
        height: data.height,
        z_index: data.z_index,
        metadata: data.metadata
      })
    } catch (e) {
      console.error("[Canvas] Failed to duplicate component:", e)
    }
  }

  async deleteComponent(comp) {
    const compId = comp.dataset.componentId
    const pageId = this.pageIdValue
    if (!compId || !pageId) return

    // Clean up widget behavior before removal
    this.destroyComponent(comp)
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
    // Don't drag while editing
    if (this.editingComponent) return
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
