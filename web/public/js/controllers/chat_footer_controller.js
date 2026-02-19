import { Controller } from "https://cdn.jsdelivr.net/npm/@hotwired/stimulus@3.2.2/dist/stimulus.js"

export default class extends Controller {
  static targets = ["tabBar", "canvasTabs", "conversationTabs", "conversationTabBar", "panels"]

  connect() {
    // State: array of canvas objects, each with nested conversations
    // { pageId, title, slug, conversations: [{ id, title, slug }], activeConvId }
    this.canvases = []
    this.activeCanvasPageId = null
    this.activeEventSource = null // single SSE connection for active canvas
    this.footerHeight = parseInt(sessionStorage.getItem("chatFooterHeight")) || 350

    // Expose for cross-component access
    window.chatFooter = this

    // Restore from sessionStorage
    const saved = sessionStorage.getItem("chatState")
    if (saved) {
      try {
        const state = JSON.parse(saved)
        if (state.canvases && state.canvases.length > 0) {
          this.element.style.height = this.footerHeight + "px"
          for (const canvas of state.canvases) {
            this._restoreCanvas(canvas)
          }
          if (state.activeCanvasPageId) {
            this.switchCanvas(state.activeCanvasPageId)
          }
          return
        }
      } catch (e) { /* ignore bad data */ }
    }

    // Discard old format
    sessionStorage.removeItem("chatOpenTabs")

    // Start collapsed
    this.element.style.height = "auto"

    // Handle browser back/forward
    window.addEventListener("popstate", () => this._handlePopState())
  }

  disconnect() {
    if (this.activeEventSource) {
      this.activeEventSource.close()
      this.activeEventSource = null
    }
    window.chatFooter = null
  }

  // --- Canvas Tab Management ---

  async newTab() {
    try {
      const resp = await fetch("/api/canvases", {
        method: "POST",
        headers: { "Content-Type": "application/json" }
      })
      const data = await resp.json()
      this.openCanvas(data.ai_page_id, data.title, data.page_slug, data.id, data.title, data.conv_slug)
    } catch (e) {
      console.error("[ChatFooter] Failed to create canvas:", e)
    }
  }

  openCanvas(pageId, title, slug, convId, convTitle, convSlug) {
    let canvas = this.canvases.find(c => c.pageId === pageId)

    if (!canvas) {
      canvas = { pageId, title, slug, conversations: [], activeConvId: null }
      this.canvases.push(canvas)

      // Create canvas tab button
      this._createCanvasTabButton(canvas)

      // Create canvas overlay div
      this._createCanvasOverlay(pageId)
    }

    // Expand footer if collapsed
    if (!this.element.style.height || this.element.style.height === "auto") {
      this.element.style.height = this.footerHeight + "px"
    }

    // Switch to this canvas
    this.switchCanvas(pageId)

    // Open conversation if provided, otherwise create one if canvas has none
    if (convId) {
      this.openConversation(convId, convTitle, convSlug, pageId)
    } else if (canvas.conversations.length === 0) {
      this.newConversation()
    }
  }

  switchCanvas(pageId) {
    // Switch SSE to new active canvas
    if (this.activeCanvasPageId !== pageId) {
      if (this.activeEventSource) {
        this.activeEventSource.close()
        this.activeEventSource = null
      }
      this.connectSSE(pageId)
    }

    this.activeCanvasPageId = pageId
    const canvas = this.canvases.find(c => c.pageId === pageId)

    // Update canvas tab buttons
    this.canvasTabsTarget.querySelectorAll(".chat-tab").forEach(tab => {
      tab.classList.toggle("active", parseInt(tab.dataset.pageId) === pageId)
    })

    // Update canvas overlays
    const canvasesEl = document.getElementById("conversation-canvases")
    if (canvasesEl) {
      canvasesEl.querySelectorAll(".conversation-canvas").forEach(c => {
        c.classList.toggle("active", c.id === `canvas-page-${pageId}`)
      })
    }

    // Render conversation tabs for active canvas
    this._renderConversationTabs()

    // Show/hide conversation tab bar
    if (canvas) {
      this.conversationTabBarTarget.style.display = ""
    }

    // Switch to active conversation in this canvas
    if (canvas && canvas.activeConvId) {
      this._activateConversation(canvas.activeConvId)
    }

    this._saveState()
    this._updateURL()
  }

  closeCanvas(pageId) {
    const canvas = this.canvases.find(c => c.pageId === pageId)
    if (!canvas) return

    // Close SSE if this was the active canvas
    if (this.activeCanvasPageId === pageId && this.activeEventSource) {
      this.activeEventSource.close()
      this.activeEventSource = null
    }

    // Remove all conversation panels
    for (const conv of canvas.conversations) {
      const panel = this.panelsTarget.querySelector(`[data-panel-id="${conv.id}"]`)
      if (panel) panel.remove()
    }

    // Remove canvas tab button
    const tab = this.canvasTabsTarget.querySelector(`[data-page-id="${pageId}"]`)
    if (tab) tab.remove()

    // Remove canvas overlay
    const overlay = document.getElementById(`canvas-page-${pageId}`)
    if (overlay) overlay.remove()

    // Update state
    this.canvases = this.canvases.filter(c => c.pageId !== pageId)
    this._saveState()

    // Switch to another canvas or collapse
    if (this.activeCanvasPageId === pageId) {
      if (this.canvases.length > 0) {
        this.switchCanvas(this.canvases[this.canvases.length - 1].pageId)
      } else {
        this.activeCanvasPageId = null
        this.element.style.height = "auto"
        this.conversationTabBarTarget.style.display = "none"
        this._clearConversationTabs()
        const canvasesEl = document.getElementById("conversation-canvases")
        if (canvasesEl) {
          canvasesEl.querySelectorAll(".conversation-canvas").forEach(c => c.classList.remove("active"))
        }
        this._updateURL()
      }
    }
  }

  // --- Conversation Tab Management ---

  async newConversation() {
    const canvas = this.canvases.find(c => c.pageId === this.activeCanvasPageId)
    if (!canvas) return

    try {
      const resp = await fetch("/api/conversations", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: `ai_page_id=${canvas.pageId}`
      })
      const data = await resp.json()
      this.openConversation(data.id, data.title, data.slug, canvas.pageId)
    } catch (e) {
      console.error("[ChatFooter] Failed to create conversation:", e)
    }
  }

  openConversation(convId, title, slug, pageId) {
    const canvas = this.canvases.find(c => c.pageId === pageId)
    if (!canvas) return

    // Don't duplicate
    if (canvas.conversations.find(c => c.id === convId)) {
      this.switchConversation(convId)
      return
    }

    canvas.conversations.push({ id: convId, title, slug })

    // Create panel
    const panel = document.createElement("div")
    panel.className = "chat-panel"
    panel.dataset.panelId = convId
    panel.innerHTML = `<div class="chat-panel-loading">Loading...</div>`
    this.panelsTarget.appendChild(panel)

    // Load panel content
    this._loadPanel(convId, panel)

    // If this canvas is active, re-render conversation tabs and switch
    if (this.activeCanvasPageId === pageId) {
      this._renderConversationTabs()
      this.switchConversation(convId)
    }

    this._saveState()
  }

  switchConversation(convId) {
    const canvas = this.canvases.find(c => c.pageId === this.activeCanvasPageId)
    if (!canvas) return

    canvas.activeConvId = convId
    this._activateConversation(convId)
    this._saveState()
    this._updateURL()
  }

  closeConversation(convId) {
    const canvas = this.canvases.find(c => c.conversations.some(cv => cv.id === convId))
    if (!canvas) return

    // Remove panel
    const panel = this.panelsTarget.querySelector(`[data-panel-id="${convId}"]`)
    if (panel) panel.remove()

    // Remove from state
    canvas.conversations = canvas.conversations.filter(c => c.id !== convId)

    // If it was the active conversation, switch to another or close canvas
    if (canvas.activeConvId === convId) {
      if (canvas.conversations.length > 0) {
        canvas.activeConvId = canvas.conversations[canvas.conversations.length - 1].id
      } else {
        canvas.activeConvId = null
        // Close the canvas if no conversations left
        this.closeCanvas(canvas.pageId)
        return
      }
    }

    if (this.activeCanvasPageId === canvas.pageId) {
      this._renderConversationTabs()
      if (canvas.activeConvId) {
        this._activateConversation(canvas.activeConvId)
      }
    }

    this._saveState()
    this._updateURL()
  }

  // --- SSE ---

  connectSSE(pageId) {
    if (this.activeEventSource) {
      this.activeEventSource.close()
    }

    const source = new EventSource(`/api/pages/${pageId}/stream`)
    source.onmessage = (event) => {
      window.Turbo.renderStreamMessage(event.data)
      // Auto-scroll any visible message panel for this canvas
      const canvas = this.canvases.find(c => c.pageId === pageId)
      if (canvas && canvas.activeConvId) {
        // Remove thinking indicator
        const thinking = document.getElementById(`thinking-${canvas.activeConvId}`)
        if (thinking) thinking.remove()

        const msgs = document.getElementById(`messages-${canvas.activeConvId}`)
        if (msgs) {
          requestAnimationFrame(() => { msgs.scrollTop = msgs.scrollHeight })
        }
      }
    }
    source.onerror = () => {
      console.warn(`[ChatFooter] SSE error for canvas ${pageId}, reconnecting...`)
    }
    this.activeEventSource = source
  }

  // --- Message Sending ---

  async sendMessage(event) {
    event.preventDefault()
    const form = event.target
    const textarea = form.querySelector("textarea")
    const content = textarea.value.trim()
    if (!content) return

    const conversationId = form.querySelector("[name=conversation_id]").value

    // Append user message immediately
    const messagesEl = document.getElementById(`messages-${conversationId}`)
    if (messagesEl) {
      const emptyState = messagesEl.querySelector(".py-12.text-center")
      if (emptyState) emptyState.remove()

      const msgDiv = document.createElement("div")
      msgDiv.className = "chat-msg user"
      msgDiv.innerHTML = `
        <div class="msg-meta flex items-center gap-2 mb-1">
          <span>YOU</span>
          <time>${new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}</time>
        </div>
        <div class="prose-bubble"><p>${this.escapeHtml(content)}</p></div>
      `
      messagesEl.appendChild(msgDiv)
      requestAnimationFrame(() => { messagesEl.scrollTop = messagesEl.scrollHeight })
    }

    textarea.value = ""
    textarea.style.height = "auto"

    // Show AI thinking indicator
    if (messagesEl) {
      const thinkingDiv = document.createElement("div")
      thinkingDiv.className = "ai-thinking"
      thinkingDiv.id = `thinking-${conversationId}`
      thinkingDiv.innerHTML = `
        <div class="ai-thinking-dots">
          <div class="ai-thinking-dot"></div>
          <div class="ai-thinking-dot"></div>
          <div class="ai-thinking-dot"></div>
        </div>
      `
      messagesEl.appendChild(thinkingDiv)
      requestAnimationFrame(() => { messagesEl.scrollTop = messagesEl.scrollHeight })
    }

    try {
      await fetch(`/conversations/${conversationId}/messages`, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: `content=${encodeURIComponent(content)}`
      })
    } catch (e) {
      console.error("[ChatFooter] Failed to send message:", e)
    }
  }

  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault()
      event.target.closest("form").requestSubmit()
    }
  }

  autoResize(event) {
    const textarea = event.target
    textarea.style.height = "auto"
    textarea.style.height = Math.min(textarea.scrollHeight, 120) + "px"
  }

  // --- Resize ---

  startResize(event) {
    event.preventDefault()
    const startY = event.type === "touchstart" ? event.touches[0].clientY : event.clientY
    const startHeight = this.element.offsetHeight

    const onMove = (e) => {
      const currentY = e.type === "touchmove" ? e.touches[0].clientY : e.clientY
      const newHeight = Math.min(Math.max(startHeight + (startY - currentY), 150), window.innerHeight - 80)
      this.element.style.height = newHeight + "px"
      this.footerHeight = newHeight
    }

    const onUp = () => {
      document.removeEventListener("mousemove", onMove)
      document.removeEventListener("mouseup", onUp)
      document.removeEventListener("touchmove", onMove)
      document.removeEventListener("touchend", onUp)
      sessionStorage.setItem("chatFooterHeight", this.footerHeight)
    }

    document.addEventListener("mousemove", onMove)
    document.addEventListener("mouseup", onUp)
    document.addEventListener("touchmove", onMove)
    document.addEventListener("touchend", onUp)
  }

  // --- Internal Helpers ---

  _createCanvasTabButton(canvas) {
    const tab = document.createElement("button")
    tab.type = "button"
    tab.className = "chat-tab"
    tab.dataset.pageId = canvas.pageId
    tab.innerHTML = `
      <span class="chat-tab-title">${this.escapeHtml(canvas.title || `Canvas ${canvas.pageId}`)}</span>
      <span class="chat-tab-close">&times;</span>
    `
    tab.querySelector(".chat-tab-close").addEventListener("click", (e) => {
      e.stopPropagation()
      this.closeCanvas(canvas.pageId)
    })
    tab.addEventListener("click", () => {
      this.switchCanvas(canvas.pageId)
    })
    this.canvasTabsTarget.appendChild(tab)
  }

  _createCanvasOverlay(pageId) {
    const canvasesEl = document.getElementById("conversation-canvases")
    const canvasId = `canvas-page-${pageId}`
    if (canvasesEl && !document.getElementById(canvasId)) {
      const overlay = document.createElement("div")
      overlay.id = canvasId
      overlay.className = "conversation-canvas"
      canvasesEl.appendChild(overlay)
      this._loadCanvasByPage(pageId, overlay)
    }
  }

  _renderConversationTabs() {
    this._clearConversationTabs()
    const canvas = this.canvases.find(c => c.pageId === this.activeCanvasPageId)
    if (!canvas) return

    for (const conv of canvas.conversations) {
      const tab = document.createElement("button")
      tab.type = "button"
      tab.className = "chat-tab"
      tab.dataset.convId = conv.id
      if (canvas.activeConvId === conv.id) tab.classList.add("active")
      tab.innerHTML = `
        <span class="chat-tab-title">${this.escapeHtml(conv.title || `Chat ${conv.id}`)}</span>
        <span class="chat-tab-close">&times;</span>
      `
      tab.querySelector(".chat-tab-close").addEventListener("click", (e) => {
        e.stopPropagation()
        this.closeConversation(conv.id)
      })
      tab.addEventListener("click", () => {
        this.switchConversation(conv.id)
      })
      this.conversationTabsTarget.appendChild(tab)
    }
  }

  _clearConversationTabs() {
    this.conversationTabsTarget.innerHTML = ""
  }

  _activateConversation(convId) {
    // Update conversation tab highlights
    this.conversationTabsTarget.querySelectorAll(".chat-tab").forEach(tab => {
      tab.classList.toggle("active", parseInt(tab.dataset.convId) === convId)
    })

    // Update panels
    this.panelsTarget.querySelectorAll(".chat-panel").forEach(panel => {
      // Show only panels belonging to the active canvas's conversations
      const canvas = this.canvases.find(c => c.pageId === this.activeCanvasPageId)
      const belongsToCanvas = canvas && canvas.conversations.some(cv => cv.id === parseInt(panel.dataset.panelId))
      panel.classList.toggle("active", belongsToCanvas && parseInt(panel.dataset.panelId) === convId)
    })

    // Scroll messages to bottom
    const msgs = document.getElementById(`messages-${convId}`)
    if (msgs) {
      requestAnimationFrame(() => { msgs.scrollTop = msgs.scrollHeight })
    }
  }

  async _loadPanel(id, panel) {
    try {
      const resp = await fetch(`/conversations/${id}/panel`)
      panel.innerHTML = await resp.text()
      const msgs = panel.querySelector(`#messages-${id}`)
      if (msgs) {
        requestAnimationFrame(() => { msgs.scrollTop = msgs.scrollHeight })
      }
    } catch (e) {
      panel.innerHTML = `<div class="p-4 text-fang-muted-fg text-sm">Failed to load conversation.</div>`
    }
  }

  async _loadCanvasByPage(pageId, container) {
    try {
      const resp = await fetch(`/api/pages/${pageId}/canvas`)
      if (!resp.ok) return

      const data = await resp.json()

      container.innerHTML = `
        <div class="canvas-dot-grid"></div>
        <div class="canvas-world" id="canvas-components-${pageId}"></div>
        <div class="canvas-zoom-indicator">100%</div>
      `
      container.setAttribute("data-controller", "canvas")
      container.setAttribute("data-canvas-page-id-value", pageId)

      // Pass scroll lock state from canvas_state
      if (data.canvas_state && data.canvas_state.scroll_locked) {
        container.setAttribute("data-canvas-scroll-locked-value", "true")
      }

      const world = container.querySelector(".canvas-world")
      for (const comp of data.components) {
        world.insertAdjacentHTML("beforeend", this._renderCanvasComponent(comp))
      }
    } catch (e) {
      console.error("[ChatFooter] Failed to load canvas:", e)
    }
  }

  _renderCanvasComponent(comp) {
    // Use server-rendered HTML which includes header, drag handle, etc.
    if (comp.html) return comp.html

    // Fallback for legacy responses
    let style = `left:${comp.x}px;top:${comp.y}px;width:${comp.width}px;`
    if (comp.height) style += `height:${comp.height}px;`
    const metaJson = JSON.stringify(comp.metadata || {}).replace(/"/g, '&quot;')
    return `<div class="canvas-component" id="canvas-component-${comp.id}" data-component-id="${comp.id}" data-widget-type="${comp.type || ''}" data-widget-metadata="${metaJson}" style="${style}" data-z="${comp.z_index}">
      <div class="canvas-component-content">${comp.content || ''}</div>
    </div>`
  }

  // --- Restore canvas from saved state ---

  _restoreCanvas(savedCanvas) {
    const canvas = {
      pageId: savedCanvas.pageId,
      title: savedCanvas.title,
      slug: savedCanvas.slug,
      conversations: [],
      activeConvId: savedCanvas.activeConvId
    }
    this.canvases.push(canvas)

    this._createCanvasTabButton(canvas)
    this._createCanvasOverlay(canvas.pageId)

    // Restore conversations
    for (const conv of (savedCanvas.conversations || [])) {
      canvas.conversations.push({ id: conv.id, title: conv.title, slug: conv.slug })

      const panel = document.createElement("div")
      panel.className = "chat-panel"
      panel.dataset.panelId = conv.id
      panel.innerHTML = `<div class="chat-panel-loading">Loading...</div>`
      this.panelsTarget.appendChild(panel)
      this._loadPanel(conv.id, panel)
    }
  }

  // --- URL Management ---

  _updateURL() {
    const canvas = this.canvases.find(c => c.pageId === this.activeCanvasPageId)
    if (!canvas) {
      if (location.pathname !== "/") history.pushState(null, "", "/")
      return
    }
    const conv = canvas.conversations.find(c => c.id === canvas.activeConvId)
    const path = conv ? `/${canvas.slug}/${conv.slug}` : `/${canvas.slug}`
    if (location.pathname !== path) history.pushState(null, "", path)
  }

  _handlePopState() {
    const parts = location.pathname.split("/").filter(Boolean)
    if (parts.length === 0) {
      // At root — deselect
      if (this.activeCanvasPageId) {
        this.activeCanvasPageId = null
        this.canvasTabsTarget.querySelectorAll(".chat-tab").forEach(t => t.classList.remove("active"))
        this.conversationTabBarTarget.style.display = "none"
        this._clearConversationTabs()
        this.panelsTarget.querySelectorAll(".chat-panel").forEach(p => p.classList.remove("active"))
        const canvasesEl = document.getElementById("conversation-canvases")
        if (canvasesEl) canvasesEl.querySelectorAll(".conversation-canvas").forEach(c => c.classList.remove("active"))
      }
      return
    }

    const canvasSlug = parts[0]
    const chatSlug = parts[1]

    const canvas = this.canvases.find(c => c.slug === canvasSlug)
    if (canvas) {
      this.switchCanvas(canvas.pageId)
      if (chatSlug) {
        const conv = canvas.conversations.find(c => c.slug === chatSlug)
        if (conv) this.switchConversation(conv.id)
      }
    }
  }

  // --- Persistence ---

  _saveState() {
    const state = {
      canvases: this.canvases.map(c => ({
        pageId: c.pageId,
        title: c.title,
        slug: c.slug,
        conversations: c.conversations.map(cv => ({ id: cv.id, title: cv.title, slug: cv.slug })),
        activeConvId: c.activeConvId
      })),
      activeCanvasPageId: this.activeCanvasPageId
    }
    sessionStorage.setItem("chatState", JSON.stringify(state))
  }

  // --- Utilities ---

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
