import { Application } from "https://cdn.jsdelivr.net/npm/@hotwired/stimulus@3.2.2/dist/stimulus.js"
import * as Turbo from "https://cdn.jsdelivr.net/npm/@hotwired/turbo@8.0.0/dist/turbo.es2017-esm.js"

window.Turbo = Turbo

const application = Application.start()

// Import controllers
import ConversationController from "/js/controllers/conversation_controller.js"
import NotificationsController from "/js/controllers/notifications_controller.js"
application.register("conversation", ConversationController)
application.register("notifications", NotificationsController)
