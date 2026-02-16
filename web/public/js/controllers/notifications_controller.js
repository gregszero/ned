import { Controller } from "https://cdn.jsdelivr.net/npm/@hotwired/stimulus@3.2.2/dist/stimulus.js"

export default class extends Controller {
  connect() {
    this.source = new EventSource('/notifications/stream')
    this.source.onmessage = (event) => {
      window.Turbo.renderStreamMessage(event.data)
    }
  }

  disconnect() {
    this.source?.close()
  }
}
