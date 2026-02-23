import { Controller } from "https://cdn.jsdelivr.net/npm/@hotwired/stimulus@3.2.2/dist/stimulus.js"

export default class extends Controller {
  static values = { pageId: Number, scrollLocked: { type: Boolean, default: false } }

  connect() {
    this.scale = 1.0
    this.panX = 0
    this.panY = 0
    this.isPanning = false
    this.isDragging = false
    this.isResizing = false
    this.dragTarget = null
    this.resizeTarget = null
    this.startX = 0
    this.startY = 0
    this.startElX = 0
    this.startElY = 0
    this.scrollLock = this.scrollLockedValue
    this.editLock = false

    this.world = this.element.querySelector(".canvas-world")
    if (!this.world) return

    // Apply scroll lock class if initial value is true
    if (this.scrollLock) {
      this.element.classList.add("scroll-locked")
    }

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

    // Selection + floating toolbar
    this.selectedComponent = null
    this.toolbar = null
    this.colorPicker = null

    // Configurable menu item registries — built from widget types API
    this.canvasMenuItems = [
      { label: "Add Note", action: (wx, wy) => this.addWidget('card', wx, wy) },
      { separator: true },
      { label: () => this.scrollLock ? "Scroll Lock: On" : "Scroll Lock: Off", action: () => this.toggleScrollLock() },
      { label: () => this.editLock ? "Edit Lock: On" : "Edit Lock: Off", action: () => this.toggleEditLock() },
      { label: "Reset View", action: () => this.resetView() },
    ]

    // Fetch widget types and rebuild menu dynamically
    this._loadWidgetTypes()

    this.componentMenuItems = [
      { label: "Chat about this", action: (comp) => this.chatAboutComponent(comp) },
      { label: "Duplicate", action: (comp) => this.duplicateComponent(comp) },
      { separator: true },
      { label: "Delete", destructive: true, action: (comp) => this.deleteComponent(comp) },
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
    this.deselectComponent()
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
    if (!component) {
      // Double-click on empty canvas — open context menu at that position
      const rect = this.element.getBoundingClientRect()
      const worldX = (e.clientX - rect.left - this.panX) / this.scale
      const worldY = (e.clientY - rect.top - this.panY) / this.scale
      this.showCanvasMenu(e.clientX, e.clientY, worldX, worldY)
      return
    }

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
    component.style.cursor = ""
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
    if (!component) {
      // Only show context menu on canvas background
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
      } else if (item.submenu) {
        const wrapper = document.createElement("div")
        wrapper.className = "canvas-context-menu-item-wrapper"
        const btn = document.createElement("button")
        btn.className = "canvas-context-menu-item has-submenu"
        btn.textContent = item.label
        wrapper.appendChild(btn)

        const sub = document.createElement("div")
        sub.className = "canvas-context-menu canvas-context-submenu"
        for (const subItem of item.submenu) {
          const subBtn = document.createElement("button")
          subBtn.className = "canvas-context-menu-item"
          subBtn.textContent = typeof subItem.label === "function" ? subItem.label() : subItem.label
          subBtn.addEventListener("click", () => { this.hideMenu(); subItem.action(worldX, worldY) })
          sub.appendChild(subBtn)
        }
        wrapper.appendChild(sub)
        this.menuItems.appendChild(wrapper)
      } else {
        const label = typeof item.label === "function" ? item.label() : item.label
        const btn = document.createElement("button")
        btn.className = "canvas-context-menu-item"
        btn.textContent = label
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
        const label = typeof item.label === "function" ? item.label() : item.label
        const btn = document.createElement("button")
        btn.className = "canvas-context-menu-item" + (item.destructive ? " destructive" : "")
        btn.textContent = label
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
    // Deselect when clicking outside the canvas
    if (this.selectedComponent && !this.element.contains(e.target)) this.deselectComponent()
  }

  onKeyDown(e) {
    if (e.key === "Escape") {
      this.hideMenu()
      this.deselectComponent()
    }
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

      // Group widget types by category for submenu rendering
      const groups = {}
      const ungrouped = []
      for (const w of this._widgetTypes) {
        if (w.category) {
          if (!groups[w.category]) groups[w.category] = []
          groups[w.category].push({ label: w.label, action: (wx, wy) => this.addWidget(w.type, wx, wy) })
        } else {
          ungrouped.push({ label: w.label, action: (wx, wy) => this.addWidget(w.type, wx, wy) })
        }
      }

      const categoryOrder = ['Content', 'Data', 'System']
      const categoryItems = categoryOrder
        .filter(cat => groups[cat])
        .map(cat => ({ label: cat, submenu: groups[cat] }))

      // Any uncategorized widgets go into a "Custom" group if there are several, otherwise top-level
      if (ungrouped.length > 3) {
        categoryItems.push({ label: 'Custom', submenu: ungrouped })
      }

      const utilityItems = [
        { label: () => this.scrollLock ? "Scroll Lock: On" : "Scroll Lock: Off", action: () => this.toggleScrollLock() },
        { label: () => this.editLock ? "Edit Lock: On" : "Edit Lock: Off", action: () => this.toggleEditLock() },
        { label: "Reset View", action: () => this.resetView() },
      ]

      const topLevel = ungrouped.length <= 3 ? ungrouped : []
      this.canvasMenuItems = [...categoryItems, ...topLevel, { separator: true }, ...utilityItems]
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

  async refreshComponent(comp) {
    const compId = comp.dataset.componentId
    if (!compId) return

    // Visual feedback: spin the refresh button
    const refreshBtn = this.toolbar?.querySelector('[data-action="refresh"]')
    if (refreshBtn) refreshBtn.classList.add("spinning")

    try {
      await fetch('/api/actions', {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ action_type: 'refresh_component', component_id: compId })
      })
    } catch (e) {
      console.error("[Canvas] Failed to refresh component:", e)
    } finally {
      if (refreshBtn) refreshBtn.classList.remove("spinning")
    }
  }

  // --- Selection & Floating Toolbar ---

  selectComponent(comp) {
    if (this.selectedComponent === comp) return
    this.deselectComponent()
    this.selectedComponent = comp
    comp.classList.add("selected")
    this.showToolbar(comp)
  }

  deselectComponent() {
    if (this.selectedComponent) {
      this.selectedComponent.classList.remove("selected")
      this.selectedComponent = null
    }
    this.hideToolbar()
  }

  showToolbar(comp) {
    this.hideToolbar()
    const tb = document.createElement("div")
    tb.className = "canvas-component-toolbar"
    tb.id = "canvas-component-toolbar"

    const paletteIcon = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="13.5" cy="6.5" r="0.5" fill="currentColor"/><circle cx="17.5" cy="10.5" r="0.5" fill="currentColor"/><circle cx="8.5" cy="7.5" r="0.5" fill="currentColor"/><circle cx="6.5" cy="12" r="0.5" fill="currentColor"/><path d="M12 2C6.5 2 2 6.5 2 12s4.5 10 10 10c.926 0 1.648-.746 1.648-1.688 0-.437-.18-.835-.437-1.125-.29-.289-.438-.652-.438-1.125a1.64 1.64 0 0 1 1.668-1.668h1.996c3.051 0 5.555-2.503 5.555-5.554C21.965 6.012 17.461 2 12 2Z"/></svg>`
    const refreshIcon = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="23 4 23 10 17 10"/><polyline points="1 20 1 14 7 14"/><path d="M3.51 9a9 9 0 0 1 14.85-3.36L23 10M1 14l4.64 4.36A9 9 0 0 0 20.49 15"/></svg>`
    const chatIcon = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>`
    const copyIcon = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>`
    const trashIcon = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/></svg>`

    const btn = (action, title, content, cls = '') => {
      const b = document.createElement("button")
      b.dataset.action = action
      b.title = title
      b.innerHTML = content
      if (cls) b.className = cls
      return b
    }

    const sep = () => {
      const d = document.createElement("div")
      d.className = "toolbar-separator"
      return d
    }

    // Build toolbar
    tb.appendChild(btn("style", "Color", paletteIcon))
    tb.appendChild(sep())
    tb.appendChild(btn("font-sm", "Small text", "A"))
    tb.appendChild(btn("font-md", "Medium text", "A"))
    tb.appendChild(btn("font-lg", "Large text", "A"))
    tb.appendChild(sep())
    // Refresh button for refreshable widgets
    const widgetType = comp.dataset.widgetType
    const widgetInfo = this._widgetTypes?.find(w => w.type === widgetType)
    if (widgetInfo?.refreshable) {
      tb.appendChild(btn("refresh", "Refresh", refreshIcon))
    }
    tb.appendChild(btn("chat", "Chat about this", chatIcon))
    tb.appendChild(btn("duplicate", "Duplicate", copyIcon))
    tb.appendChild(btn("delete", "Delete", trashIcon, "destructive"))

    // Style font size buttons
    const fontBtns = tb.querySelectorAll('[data-action^="font-"]')
    fontBtns[0].style.fontSize = "0.625rem"
    fontBtns[2].style.fontSize = "0.875rem"
    // Highlight current font size
    const meta = JSON.parse(comp.dataset.widgetMetadata || '{}')
    const currentSize = meta.font_size || 'md'
    fontBtns.forEach(b => { if (b.dataset.action === `font-${currentSize}`) b.classList.add("active") })

    // Event delegation
    tb.addEventListener("click", (e) => {
      const target = e.target.closest("button")
      if (!target) return
      e.stopPropagation()
      const action = target.dataset.action
      switch (action) {
        case "style": this.toggleColorPicker(tb, comp); break
        case "font-sm": this.setFontSize(comp, "sm"); break
        case "font-md": this.setFontSize(comp, "md"); break
        case "font-lg": this.setFontSize(comp, "lg"); break
        case "refresh": this.refreshComponent(comp); break
        case "chat": this.chatAboutComponent(comp); this.deselectComponent(); break
        case "duplicate": this.duplicateComponent(comp); this.deselectComponent(); break
        case "delete": this.deleteComponent(comp); this.deselectComponent(); break
      }
    })

    this.world.appendChild(tb)
    this.toolbar = tb
    this.positionToolbar(comp)
  }

  positionToolbar(comp) {
    if (!this.toolbar) return
    const compX = parseFloat(comp.style.left) || 0
    const compY = parseFloat(comp.style.top) || 0
    const compW = comp.offsetWidth
    const compH = comp.offsetHeight
    const tbW = this.toolbar.offsetWidth
    this.toolbar.style.left = (compX + compW / 2 - tbW / 2) + "px"
    this.toolbar.style.top = (compY + compH + 8) + "px"
  }

  hideToolbar() {
    this.hideColorPicker()
    if (this.toolbar) {
      this.toolbar.remove()
      this.toolbar = null
    }
  }

  toggleColorPicker(toolbar, comp) {
    if (this.colorPicker) { this.hideColorPicker(); return }
    const colors = ['#ef4444', '#f97316', '#f59e0b', '#22c55e', '#14b8a6', '#60a5fa', '#a78bfa', '#a1a1aa']
    const picker = document.createElement("div")
    picker.className = "toolbar-color-picker"
    colors.forEach(c => {
      const swatch = document.createElement("div")
      swatch.className = "color-swatch"
      swatch.style.background = c
      swatch.addEventListener("click", (e) => {
        e.stopPropagation()
        this.setHeaderColor(comp, c)
        this.hideColorPicker()
      })
      picker.appendChild(swatch)
    })
    // Position relative to the style button
    const styleBtn = toolbar.querySelector('[data-action="style"]')
    picker.style.position = "absolute"
    picker.style.bottom = "calc(100% + 4px)"
    picker.style.left = `${styleBtn.offsetLeft - 60}px`
    toolbar.appendChild(picker)
    this.colorPicker = picker
  }

  hideColorPicker() {
    if (this.colorPicker) {
      this.colorPicker.remove()
      this.colorPicker = null
    }
  }

  setHeaderColor(comp, color) {
    const meta = JSON.parse(comp.dataset.widgetMetadata || '{}')
    meta.title_color = color
    comp.dataset.widgetMetadata = JSON.stringify(meta)
    // Update the header color visually
    const header = comp.querySelector(".canvas-component-header")
    if (header) header.style.color = color
    // Persist
    this.patchComponentMetadata(comp, meta)
  }

  setFontSize(comp, size) {
    comp.classList.remove("font-sm", "font-lg")
    if (size !== "md") comp.classList.add(`font-${size}`)
    const meta = JSON.parse(comp.dataset.widgetMetadata || '{}')
    meta.font_size = size
    comp.dataset.widgetMetadata = JSON.stringify(meta)
    this.patchComponentMetadata(comp, meta)
    // Update active state on toolbar buttons
    if (this.toolbar) {
      this.toolbar.querySelectorAll('[data-action^="font-"]').forEach(b => {
        b.classList.toggle("active", b.dataset.action === `font-${size}`)
      })
    }
  }

  async patchComponentMetadata(comp, meta) {
    const compId = comp.dataset.componentId
    const pageId = this.pageIdValue
    if (!compId || !pageId) return
    try {
      await fetch(`/api/pages/${pageId}/components/${compId}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ metadata: meta })
      })
    } catch (e) {
      console.error("[Canvas] Failed to update metadata:", e)
    }
  }

  toggleScrollLock() {
    this.scrollLock = !this.scrollLock
    this.element.classList.toggle("scroll-locked", this.scrollLock)
    this.updateZoomIndicator()
  }

  toggleEditLock() {
    this.editLock = !this.editLock
    this.element.classList.toggle("edit-locked", this.editLock)
    this.updateZoomIndicator()
  }

  updateScrollLockIndicator() {
    // Merged into updateZoomIndicator
    this.updateZoomIndicator()
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

    // Ignore clicks inside toolbar
    if (e.target.closest(".canvas-component-toolbar") || e.target.closest(".toolbar-color-picker")) return

    const component = e.target.closest(".canvas-component")
    if (component && this.editLock) {
      // Edit lock: let the event pass through for normal HTML behavior
      return
    }
    if (component) {
      // Select component + show toolbar
      this.selectComponent(component)
      // Check for resize handle
      const resizeHandle = e.target.closest(".canvas-resize-handle")
      if (resizeHandle) {
        this.isResizing = true
        this.resizeTarget = component
        this.startX = e.clientX
        this.startY = e.clientY
        this.startWidth = component.offsetWidth
        this.startHeight = component.offsetHeight
        e.preventDefault()
        return
      }
      // Only start dragging if mousedown is on the drag handle
      const dragHandle = e.target.closest(".canvas-drag-handle")
      if (dragHandle) {
        this.isDragging = true
        this.dragTarget = component
        this.startX = e.clientX
        this.startY = e.clientY
        this.startElX = parseFloat(component.style.left) || 0
        this.startElY = parseFloat(component.style.top) || 0
        component.classList.add("dragging")
        e.preventDefault()
      }
    } else if (!this.scrollLock && (e.target === this.element || e.target === this.world || e.target.classList.contains("canvas-dot-grid"))) {
      // Deselect on canvas background click
      this.deselectComponent()
      // Start panning (disabled in scroll-lock mode)
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
    } else if (this.isResizing && this.resizeTarget) {
      const dx = (e.clientX - this.startX) / this.scale
      const dy = (e.clientY - this.startY) / this.scale
      this.resizeTarget.style.width = Math.max(120, this.startWidth + dx) + "px"
      this.resizeTarget.style.height = Math.max(60, this.startHeight + dy) + "px"
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
    if (this.isResizing && this.resizeTarget) {
      this.saveComponentSize(this.resizeTarget)
      if (this.selectedComponent === this.resizeTarget) this.positionToolbar(this.resizeTarget)
      this.isResizing = false
      this.resizeTarget = null
    }
    if (this.isDragging && this.dragTarget) {
      this.dragTarget.classList.remove("dragging")
      this.saveComponentPosition(this.dragTarget)
      // Reposition toolbar after drag
      if (this.selectedComponent === this.dragTarget) this.positionToolbar(this.dragTarget)
      this.isDragging = false
      this.dragTarget = null
    }
  }

  // --- Touch ---

  onTouchStart(e) {
    if (e.touches.length !== 1) return
    const touch = e.touches[0]
    const component = touch.target.closest(".canvas-component")
    if (component && this.editLock) {
      // Edit lock: let the event pass through for normal HTML behavior
      return
    }
    if (component) {
      // Check for resize handle
      const resizeHandle = touch.target.closest(".canvas-resize-handle")
      if (resizeHandle) {
        this.isResizing = true
        this.resizeTarget = component
        this.startX = touch.clientX
        this.startY = touch.clientY
        this.startWidth = component.offsetWidth
        this.startHeight = component.offsetHeight
        e.preventDefault()
        return
      }
      // Only start dragging if touch is on the drag handle
      const dragHandle = touch.target.closest(".canvas-drag-handle")
      if (dragHandle) {
        this.isDragging = true
        this.dragTarget = component
        this.startX = touch.clientX
        this.startY = touch.clientY
        this.startElX = parseFloat(component.style.left) || 0
        this.startElY = parseFloat(component.style.top) || 0
        component.classList.add("dragging")
        e.preventDefault()
      }
    } else if (!this.scrollLock) {
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
    } else if (this.isResizing && this.resizeTarget) {
      const dx = (touch.clientX - this.startX) / this.scale
      const dy = (touch.clientY - this.startY) / this.scale
      this.resizeTarget.style.width = Math.max(120, this.startWidth + dx) + "px"
      this.resizeTarget.style.height = Math.max(60, this.startHeight + dy) + "px"
      e.preventDefault()
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
    if (this.isResizing && this.resizeTarget) {
      this.saveComponentSize(this.resizeTarget)
      if (this.selectedComponent === this.resizeTarget) this.positionToolbar(this.resizeTarget)
      this.isResizing = false
      this.resizeTarget = null
    }
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
      // Scroll lock: wheel scrolls vertically (pans Y only)
      this.panY -= e.deltaY
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
      this.world.style.width = ""
      this.world.style.height = ""
    }
  }

  updateZoomIndicator() {
    const indicator = this.element.querySelector(".canvas-zoom-indicator")
    if (!indicator) return

    const zoom = Math.round(this.scale * 100) + "%"

    // SVG icons (14px, stroke-based, 1.5px stroke)
    const scrollIcon = `<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3v18"/><path d="m8 6 4-3 4 3"/><path d="m8 18 4 3 4-3"/></svg>`
    const editLockOffIcon = `<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M5 9l4-4 4 4"/><path d="M9 5v10"/><path d="M19 15l-4 4-4-4"/><path d="M15 19V9"/></svg>`
    const editLockOnIcon = `<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0 1 10 0v4"/></svg>`

    indicator.innerHTML = `<span>${zoom}</span><button class="canvas-toolbar-btn${this.scrollLock ? ' active' : ''}" title="Toggle scroll lock">${scrollIcon}</button><button class="canvas-toolbar-btn${this.editLock ? ' active' : ''}" title="Toggle edit lock">${this.editLock ? editLockOnIcon : editLockOffIcon}</button>`
    indicator.style.pointerEvents = "auto"

    const buttons = indicator.querySelectorAll(".canvas-toolbar-btn")
    buttons[0].onclick = (e) => { e.stopPropagation(); this.toggleScrollLock() }
    buttons[1].onclick = (e) => { e.stopPropagation(); this.toggleEditLock() }
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

  async saveComponentSize(el) {
    const componentId = el.dataset.componentId
    const pageId = this.pageIdValue
    if (!componentId || !pageId) return

    const width = Math.round(parseFloat(el.style.width) || el.offsetWidth)
    const height = Math.round(parseFloat(el.style.height) || el.offsetHeight)

    try {
      await fetch(`/api/pages/${pageId}/components/${componentId}`, {
        method: "PATCH",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: `width=${width}&height=${height}`
      })
    } catch (e) {
      console.error("[Canvas] Failed to save size:", e)
    }
  }
}
