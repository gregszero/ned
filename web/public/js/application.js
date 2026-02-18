import { Application } from "https://cdn.jsdelivr.net/npm/@hotwired/stimulus@3.2.2/dist/stimulus.js"
import * as Turbo from "https://cdn.jsdelivr.net/npm/@hotwired/turbo@8.0.0/dist/turbo.es2017-esm.js"

window.Turbo = Turbo

const application = Application.start()

// Widget behavior registry + built-in widgets
import "/js/widgets/registry.js"
import "/js/widgets/clock.js"

// Import controllers
import ConversationController from "/js/controllers/conversation_controller.js"
import NotificationsController from "/js/controllers/notifications_controller.js"
import ScrollAnimationController from "/js/controllers/scroll_animation_controller.js"
import ChatFooterController from "/js/controllers/chat_footer_controller.js"
import CanvasController from "/js/controllers/canvas_controller.js"
application.register("conversation", ConversationController)
application.register("notifications", NotificationsController)
application.register("scroll-animation", ScrollAnimationController)
application.register("chat-footer", ChatFooterController)
application.register("canvas", CanvasController)

// Close sidebar on Turbo navigation
document.addEventListener('turbo:before-visit', () => {
  const toggle = document.getElementById('sidebar-toggle');
  if (toggle) toggle.checked = false;
})
