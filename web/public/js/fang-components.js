// ned-components.js — Client-side component library for rich widgets
// Provides: chart rendering, sortable tables, action buttons, auto-init via MutationObserver

window.Ned = window.Ned || {}

// --- Chart Rendering (wraps Chart.js) ---

Ned.renderChart = function(el, config) {
  if (typeof Chart === 'undefined') {
    console.warn('[Ned] Chart.js not loaded, skipping chart render')
    return null
  }

  // Destroy existing chart on this canvas if any
  const existing = Chart.getChart(el)
  if (existing) existing.destroy()

  // Apply theme defaults
  const defaults = {
    color: getComputedStyle(document.documentElement).getPropertyValue('--muted-foreground').trim() || '#a1a1aa',
    borderColor: getComputedStyle(document.documentElement).getPropertyValue('--border').trim() || '#27272a'
  }

  const mergedOptions = Object.assign({
    responsive: true,
    maintainAspectRatio: false,
    plugins: {
      legend: { labels: { color: defaults.color } }
    },
    scales: {}
  }, config.options || {})

  // Apply theme colors to scales if not already set
  if (config.type !== 'pie' && config.type !== 'doughnut' && config.type !== 'polarArea') {
    if (!mergedOptions.scales.x) mergedOptions.scales.x = {}
    if (!mergedOptions.scales.y) mergedOptions.scales.y = {}
    mergedOptions.scales.x.ticks = Object.assign({ color: defaults.color }, mergedOptions.scales.x.ticks || {})
    mergedOptions.scales.x.grid = Object.assign({ color: defaults.borderColor }, mergedOptions.scales.x.grid || {})
    mergedOptions.scales.y.ticks = Object.assign({ color: defaults.color }, mergedOptions.scales.y.ticks || {})
    mergedOptions.scales.y.grid = Object.assign({ color: defaults.borderColor }, mergedOptions.scales.y.grid || {})
  }

  return new Chart(el, {
    type: config.type || 'bar',
    data: {
      labels: config.labels || [],
      datasets: (config.datasets || []).map(ds => Object.assign({
        borderWidth: 1
      }, ds))
    },
    options: mergedOptions
  })
}

// --- Sortable Tables ---

function initSortableTable(table) {
  if (table._nedSortable) return
  table._nedSortable = true

  const headers = table.querySelectorAll('th')
  headers.forEach((th, colIndex) => {
    th.style.cursor = 'pointer'
    th.style.userSelect = 'none'
    th.addEventListener('click', () => sortTable(table, colIndex, th))
  })
}

function sortTable(table, colIndex, th) {
  const tbody = table.querySelector('tbody') || table
  const rows = Array.from(tbody.querySelectorAll('tr'))
  const isAsc = th.dataset.sortDir !== 'asc'

  // Clear sort indicators on all headers
  table.querySelectorAll('th').forEach(h => {
    h.dataset.sortDir = ''
    h.classList.remove('sort-asc', 'sort-desc')
  })

  th.dataset.sortDir = isAsc ? 'asc' : 'desc'
  th.classList.add(isAsc ? 'sort-asc' : 'sort-desc')

  rows.sort((a, b) => {
    const aText = (a.children[colIndex]?.textContent || '').trim()
    const bText = (b.children[colIndex]?.textContent || '').trim()
    const aNum = parseFloat(aText)
    const bNum = parseFloat(bText)

    // Numeric sort if both are numbers
    if (!isNaN(aNum) && !isNaN(bNum)) {
      return isAsc ? aNum - bNum : bNum - aNum
    }
    return isAsc ? aText.localeCompare(bText) : bText.localeCompare(aText)
  })

  rows.forEach(row => tbody.appendChild(row))
}

// --- Action Buttons ---

function initActionButton(btn) {
  if (btn._nedAction) return
  btn._nedAction = true

  btn.addEventListener('click', async (e) => {
    e.preventDefault()
    if (btn.disabled) return

    let actionConfig
    try {
      actionConfig = JSON.parse(btn.dataset.nedAction)
    } catch (err) {
      console.error('[Ned] Invalid action config:', err)
      return
    }

    // Loading state
    const originalText = btn.innerHTML
    btn.disabled = true
    btn.classList.add('ned-action-loading')
    btn.innerHTML = '<span class="ned-spinner"></span> ' + (btn.dataset.loadingText || 'Working...')

    try {
      const resp = await fetch('/api/actions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(actionConfig)
      })
      const data = await resp.json()

      if (data.success) {
        btn.classList.add('ned-action-success')
        btn.innerHTML = btn.dataset.successText || 'Done'
        setTimeout(() => {
          btn.classList.remove('ned-action-success')
          btn.innerHTML = originalText
          btn.disabled = false
        }, 2000)
      } else {
        btn.classList.add('ned-action-error')
        btn.innerHTML = data.error || 'Failed'
        setTimeout(() => {
          btn.classList.remove('ned-action-error')
          btn.innerHTML = originalText
          btn.disabled = false
        }, 3000)
      }
    } catch (err) {
      console.error('[Ned] Action failed:', err)
      btn.innerHTML = 'Error'
      setTimeout(() => {
        btn.innerHTML = originalText
        btn.disabled = false
      }, 3000)
    } finally {
      btn.classList.remove('ned-action-loading')
    }
  })
}

// --- Auto-initialization ---

function initNedElements(root) {
  // Sortable tables
  root.querySelectorAll('[data-ned-table]').forEach(initSortableTable)

  // Action buttons
  root.querySelectorAll('[data-ned-action]').forEach(initActionButton)

  // Charts (initialized by widget JS, but handle standalone data-ned-chart too)
  root.querySelectorAll('[data-ned-chart]').forEach(el => {
    if (el._nedChart) return
    try {
      const config = JSON.parse(el.dataset.nedChart)
      const canvas = el.querySelector('canvas') || el
      if (canvas.tagName === 'CANVAS') {
        el._nedChart = Ned.renderChart(canvas, config)
      }
    } catch (err) {
      console.error('[Ned] Chart auto-init failed:', err)
    }
  })
}

// Init on page load
document.addEventListener('DOMContentLoaded', () => initNedElements(document))

// MutationObserver for Turbo Stream inserts
const nedObserver = new MutationObserver((mutations) => {
  for (const mutation of mutations) {
    for (const node of mutation.addedNodes) {
      if (node.nodeType === Node.ELEMENT_NODE) {
        initNedElements(node)
      }
    }
  }
})
nedObserver.observe(document.body, { childList: true, subtree: true })
