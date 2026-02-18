import { Controller } from "https://cdn.jsdelivr.net/npm/@hotwired/stimulus@3.2.2/dist/stimulus.js"

export default class extends Controller {
  static targets = ["messages"]
  static values = { id: Number, pageId: Number }

  connect() {
    this.scrollToBottom()

    // Use canvas-level SSE if pageId is available, fall back to none
    if (this.hasPageIdValue && this.pageIdValue) {
      this.source = new EventSource(`/api/pages/${this.pageIdValue}/stream`)
      this.source.onmessage = (event) => {
        window.Turbo.renderStreamMessage(event.data)
        this.scrollToBottom()
      }
      this.source.onerror = () => {
        console.warn("[SSE] Connection error, reconnecting...")
      }
    }
  }

  disconnect() {
    this.source?.close()
  }

  scrollToBottom() {
    requestAnimationFrame(() => {
      this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    })
  }
}
