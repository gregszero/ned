// Widget behavior registry
// Each widget type can register init/destroy hooks for client-side behavior
window.widgetBehaviors = {}
window.registerWidget = (type, behavior) => {
  window.widgetBehaviors[type] = behavior
}
