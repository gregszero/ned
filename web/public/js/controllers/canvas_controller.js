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
    this.observer?.disconnect()
  }

  initComponent(el) {
    el.style.zIndex = el.dataset.z || 0
  }

  // --- Pan & Drag (Mouse) ---

  onMouseDown(e) {
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
      indicator.textContent = Math.round(this.scale * 100) + "%"
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
