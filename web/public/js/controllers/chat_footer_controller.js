import { Controller } from "https://cdn.jsdelivr.net/npm/@hotwired/stimulus@3.2.2/dist/stimulus.js"

export default class extends Controller {
  static targets = ["tabBar", "tabs", "panels"]

  connect() {
    this.openTabs = [] // [{ id, title, pageId }]
    this.activeTabId = null
    this.eventSources = {} // id -> EventSource
    this.footerHeight = parseInt(sessionStorage.getItem("chatFooterHeight")) || 350

    // Expose for cross-component access
    window.chatFooter = this

    // Restore tabs from sessionStorage
    const saved = sessionStorage.getItem("chatOpenTabs")
    if (saved) {
      try {
        const tabs = JSON.parse(saved)
        if (tabs.length > 0) {
          this.element.style.height = this.footerHeight + "px"
          tabs.forEach((tab, i) => {
            this.openTab(tab.id, tab.title, i === tabs.length - 1, tab.pageId)
          })
          return
        }
      } catch (e) { /* ignore bad data */ }
    }

    // Start collapsed (just tab bar visible)
    this.element.style.height = "auto"
  }

  disconnect() {
    Object.values(this.eventSources).forEach(src => src.close())
    this.eventSources = {}
    window.chatFooter = null
  }

  // --- Tab Management ---

  async newTab() {
    try {
      const resp = await fetch("/api/canvases", {
        method: "POST",
        headers: { "Content-Type": "application/json" }
      })
      const data = await resp.json()
      this.openTab(data.id, data.title, true, data.ai_page_id)
    } catch (e) {
      console.error("[ChatFooter] Failed to create canvas:", e)
    }
  }

  openTab(id, title, activate = true, pageId = null) {
    // Don't duplicate
    if (this.openTabs.find(t => t.id === id)) {
      if (activate) this.switchTab(id)
      return
    }

    this.openTabs.push({ id, title, pageId })
    this.saveTabs()

    // Create tab button
    const tab = document.createElement("button")
    tab.type = "button"
    tab.className = "chat-tab"
    tab.dataset.tabId = id
    tab.innerHTML = `
      <span class="chat-tab-title">${this.escapeHtml(title || `Chat ${id}`)}</span>
      <span class="chat-tab-close">&times;</span>
    `
    tab.querySelector(".chat-tab-close").addEventListener("click", (e) => {
      e.stopPropagation()
      this.closeTabById(id)
    })
    tab.addEventListener("click", () => {
      this.switchTab(id)
    })
    this.tabsTarget.appendChild(tab)

    // Create panel
    const panel = document.createElement("div")
    panel.className = "chat-panel"
    panel.dataset.panelId = id
    panel.innerHTML = `<div class="chat-panel-loading">Loading...</div>`
    this.panelsTarget.appendChild(panel)

    // Create canvas div keyed by pageId
    if (pageId) {
      const canvases = document.getElementById("conversation-canvases")
      const canvasId = `canvas-page-${pageId}`
      if (canvases && !document.getElementById(canvasId)) {
        const canvas = document.createElement("div")
        canvas.id = canvasId
        canvas.className = "conversation-canvas"
        canvases.appendChild(canvas)
        // Load initial canvas content by page ID
        this.loadCanvasByPage(pageId, canvas)
      }
    }

    // Load panel content
    this.loadPanel(id, panel)

    // Connect SSE
    this.connectSSE(id)

    if (activate) {
      this.switchTab(id)
      // Expand footer if collapsed
      if (!this.element.style.height || this.element.style.height === "auto") {
        this.element.style.height = this.footerHeight + "px"
      }
    }
  }

  // Open a new conversation tab for an existing canvas page
  async openCanvasTab(pageId, title) {
    try {
      const resp = await fetch("/api/conversations", {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: `ai_page_id=${pageId}`
      })
      const data = await resp.json()
      this.openTab(data.id, title || data.title, true, pageId)
    } catch (e) {
      console.error("[ChatFooter] Failed to create conversation for canvas:", e)
    }
  }

  switchTab(id) {
    this.activeTabId = id

    // Update tab buttons
    this.tabsTarget.querySelectorAll(".chat-tab").forEach(tab => {
      tab.classList.toggle("active", tab.dataset.tabId == id)
    })

    // Update panels
    this.panelsTarget.querySelectorAll(".chat-panel").forEach(panel => {
      panel.classList.toggle("active", panel.dataset.panelId == id)
    })

    // Update canvases - show this conversation's canvas by pageId
    const canvases = document.getElementById("conversation-canvases")
    const activeTab = this.openTabs.find(t => t.id === id)
    const activePageId = activeTab?.pageId

    if (canvases) {
      canvases.querySelectorAll(".conversation-canvas").forEach(c => {
        c.classList.toggle("active", activePageId && c.id === `canvas-page-${activePageId}`)
      })
    }

    // Scroll messages to bottom
    const msgs = document.getElementById(`messages-${id}`)
    if (msgs) {
      requestAnimationFrame(() => {
        msgs.scrollTop = msgs.scrollHeight
      })
    }
  }

  closeTabById(id) {
    const tab = this.tabsTarget.querySelector(`[data-tab-id="${id}"]`)
    const closingTab = this.openTabs.find(t => t.id === id)
    const pageId = closingTab?.pageId

    // Remove SSE
    if (this.eventSources[id]) {
      this.eventSources[id].close()
      delete this.eventSources[id]
    }

    // Remove tab button and panel
    if (tab) tab.remove()
    const panel = this.panelsTarget.querySelector(`[data-panel-id="${id}"]`)
    if (panel) panel.remove()

    // Only remove canvas div if no other tab shares this pageId
    if (pageId) {
      const otherTabsWithPage = this.openTabs.filter(t => t.id !== id && t.pageId === pageId)
      if (otherTabsWithPage.length === 0) {
        const canvas = document.getElementById(`canvas-page-${pageId}`)
        if (canvas) canvas.remove()
      }
    }

    // Update state
    this.openTabs = this.openTabs.filter(t => t.id !== id)
    this.saveTabs()

    // Switch to another tab or collapse
    if (this.activeTabId === id) {
      if (this.openTabs.length > 0) {
        this.switchTab(this.openTabs[this.openTabs.length - 1].id)
      } else {
        this.activeTabId = null
        this.element.style.height = "auto"
        // Show page content again
        const canvases = document.getElementById("conversation-canvases")
        if (canvases) {
          canvases.querySelectorAll(".conversation-canvas").forEach(c => c.classList.remove("active"))
        }
      }
    }
  }

  // --- Panel Loading ---

  async loadPanel(id, panel) {
    try {
      const resp = await fetch(`/conversations/${id}/panel`)
      panel.innerHTML = await resp.text()
      // Scroll to bottom
      const msgs = panel.querySelector(`#messages-${id}`)
      if (msgs) {
        requestAnimationFrame(() => { msgs.scrollTop = msgs.scrollHeight })
      }
    } catch (e) {
      panel.innerHTML = `<div class="p-4 text-ned-muted-fg text-sm">Failed to load conversation.</div>`
    }
  }

  async loadCanvasByPage(pageId, container) {
    try {
      const resp = await fetch(`/api/pages/${pageId}/canvas`)
      if (!resp.ok) return

      const data = await resp.json()

      // Build canvas structure
      container.innerHTML = `
        <div class="canvas-dot-grid"></div>
        <div class="canvas-world" id="canvas-components-${pageId}"></div>
        <div class="canvas-zoom-indicator">100%</div>
      `
      container.setAttribute("data-controller", "canvas")
      container.setAttribute("data-canvas-page-id-value", pageId)

      const world = container.querySelector(".canvas-world")
      for (const comp of data.components) {
        world.insertAdjacentHTML("beforeend", this.renderCanvasComponent(comp))
      }
    } catch (e) {
      console.error("[ChatFooter] Failed to load canvas:", e)
    }
  }

  renderCanvasComponent(comp) {
    let style = `left:${comp.x}px;top:${comp.y}px;width:${comp.width}px;`
    if (comp.height) style += `height:${comp.height}px;`
    return `<div class="canvas-component" id="canvas-component-${comp.id}" data-component-id="${comp.id}" style="${style}" data-z="${comp.z_index}">
      <div class="canvas-component-content">${comp.content || ''}</div>
    </div>`
  }

  // --- SSE ---

  connectSSE(id) {
    if (this.eventSources[id]) return

    const source = new EventSource(`/conversations/${id}/stream`)
    source.onmessage = (event) => {
      window.Turbo.renderStreamMessage(event.data)
      // Scroll the specific panel's messages
      const msgs = document.getElementById(`messages-${id}`)
      if (msgs) {
        requestAnimationFrame(() => { msgs.scrollTop = msgs.scrollHeight })
      }
    }
    source.onerror = () => {
      console.warn(`[ChatFooter] SSE error for conversation ${id}, reconnecting...`)
    }
    this.eventSources[id] = source
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
      // Remove empty state if present
      const emptyState = messagesEl.querySelector(".py-8.text-center")
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

    // Clear input
    textarea.value = ""
    textarea.style.height = "auto"

    // Send to server
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

  // --- Persistence ---

  saveTabs() {
    sessionStorage.setItem("chatOpenTabs", JSON.stringify(this.openTabs))
  }

  // --- Utilities ---

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
