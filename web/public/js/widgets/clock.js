registerWidget('clock', {
  init(el, metadata) {
    const tz = metadata.timezone || 'UTC'
    const display = el.querySelector('[data-clock-display]')
    if (!display) return

    const tick = () => {
      display.textContent = new Date().toLocaleTimeString('en-US', {
        timeZone: tz,
        hour12: false,
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit'
      })
    }
    tick()
    el._clockInterval = setInterval(tick, 1000)
  },

  destroy(el) {
    if (el._clockInterval) {
      clearInterval(el._clockInterval)
      delete el._clockInterval
    }
  }
})
