import { Controller } from "https://cdn.jsdelivr.net/npm/@hotwired/stimulus@3.2.2/dist/stimulus.js"

export default class extends Controller {
  static targets = ["messages"]
  static values = { id: Number }

  connect() {
    this.scrollToBottom()

    this.source = new EventSource(`/conversations/${this.idValue}/stream`)
    this.source.onmessage = (event) => {
      window.Turbo.renderStreamMessage(event.data)
      this.scrollToBottom()
    }
    this.source.onerror = () => {
      // EventSource auto-reconnects; log for debugging
      console.warn("[SSE] Connection error, reconnecting...")
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
