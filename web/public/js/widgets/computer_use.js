// Computer Use widget behavior
registerWidget('computer_use', {
  init(el) {
    // Crossfade screenshots by fading new images in
    const img = el.querySelector('.cua-screen')
    if (img && img.tagName === 'IMG') {
      img.style.transition = 'opacity 0.3s ease'
    }

    // Observe mutations for screenshot updates (turbo stream replaces)
    const container = el.querySelector('.cua-container')
    if (container) {
      const observer = new MutationObserver(() => {
        const newImg = el.querySelector('.cua-screen')
        if (newImg && newImg.tagName === 'IMG') {
          newImg.style.opacity = '0'
          newImg.style.transition = 'opacity 0.3s ease'
          requestAnimationFrame(() => { newImg.style.opacity = '1' })
        }
      })
      observer.observe(container, { childList: true, subtree: true })
      el._cuaObserver = observer
    }
  },
  destroy(el) {
    if (el._cuaObserver) {
      el._cuaObserver.disconnect()
      delete el._cuaObserver
    }
  }
})
