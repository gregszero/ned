registerWidget('data_table', {
  init(el, metadata) {
    const table = el.querySelector('table.data-table')
    if (!table) return
    const cid = table.dataset.componentId

    // Sort: click sortable headers
    table.addEventListener('click', (e) => {
      const th = e.target.closest('th[data-sortable="true"]')
      if (!th) return

      const col = th.dataset.col
      const isAsc = th.classList.contains('sort-asc')
      const dir = isAsc ? 'desc' : 'asc'

      // Update header classes
      table.querySelectorAll('th').forEach(h => h.classList.remove('sort-asc', 'sort-desc'))
      th.classList.add(`sort-${dir}`)

      // Reload body frame with new sort
      const bodyFrame = el.querySelector(`#data-table-body-${cid}`)
      if (bodyFrame) {
        bodyFrame.src = `/api/tables/${cid}/rows?page=1&sort=${encodeURIComponent(col)}&dir=${dir}&frame=body`
      }
    })

    // Resize: mousedown on handle
    table.addEventListener('mousedown', (e) => {
      const handle = e.target.closest('.col-resize-handle')
      if (!handle) return
      e.preventDefault()

      const th = handle.parentElement
      const colIndex = Array.from(th.parentElement.children).indexOf(th)
      const col = table.querySelector(`colgroup`).children[colIndex]
      if (!col) return

      const startX = e.clientX
      const startWidth = th.offsetWidth

      const onMove = (me) => {
        const newWidth = Math.max(50, startWidth + me.clientX - startX)
        col.style.width = `${newWidth}px`
      }

      const onUp = () => {
        document.removeEventListener('mousemove', onMove)
        document.removeEventListener('mouseup', onUp)

        // Persist widths
        const widths = Array.from(table.querySelectorAll('colgroup col')).map(c => parseInt(c.style.width) || 150)
        const columns = (metadata.columns || []).map((c, i) => ({ ...c, width: widths[i] || c.width }))
        const pageId = el.closest('[data-page-id]')?.dataset.pageId ||
                       el.closest('.conversation-canvas')?.dataset.pageId
        if (pageId) {
          fetch(`/api/pages/${pageId}/components/${cid}`, {
            method: 'PATCH',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ metadata: { columns } })
          })
        }
      }

      document.addEventListener('mousemove', onMove)
      document.addEventListener('mouseup', onUp)
    })

    // Scroll reset on body frame reload
    const scroll = el.querySelector('.data-table-scroll')
    if (scroll) {
      document.addEventListener('turbo:frame-load', (e) => {
        if (e.target.id === `data-table-body-${cid}`) {
          scroll.scrollTop = 0
        }
      })
    }
  },

  destroy(el) {
    // No persistent intervals to clean up
  }
})
