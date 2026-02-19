// fang-components.js — Client-side component library for rich widgets
// Provides: chart rendering, sortable tables, action buttons, auto-init via MutationObserver

window.Fang = window.Fang || {}

// --- Chart Rendering (wraps Chart.js) ---

Fang.renderChart = function(el, config) {
  if (typeof Chart === 'undefined') {
    console.warn('[Fang] Chart.js not loaded, skipping chart render')
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
  if (table._fangSortable) return
  table._fangSortable = true

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
  if (btn._fangAction) return
  btn._fangAction = true

  btn.addEventListener('click', async (e) => {
    e.preventDefault()
    if (btn.disabled) return

    let actionConfig
    try {
      actionConfig = JSON.parse(btn.dataset.fangAction)
    } catch (err) {
      console.error('[Fang] Invalid action config:', err)
      return
    }

    // Loading state
    const originalText = btn.innerHTML
    btn.disabled = true
    btn.classList.add('fang-action-loading')
    btn.innerHTML = '<span class="fang-spinner"></span> ' + (btn.dataset.loadingText || 'Working...')

    try {
      const resp = await fetch('/api/actions', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(actionConfig)
      })
      const data = await resp.json()

      if (data.success) {
        btn.classList.add('fang-action-success')
        btn.innerHTML = btn.dataset.successText || 'Done'
        setTimeout(() => {
          btn.classList.remove('fang-action-success')
          btn.innerHTML = originalText
          btn.disabled = false
        }, 2000)
      } else {
        btn.classList.add('fang-action-error')
        btn.innerHTML = data.error || 'Failed'
        setTimeout(() => {
          btn.classList.remove('fang-action-error')
          btn.innerHTML = originalText
          btn.disabled = false
        }, 3000)
      }
    } catch (err) {
      console.error('[Fang] Action failed:', err)
      btn.innerHTML = 'Error'
      setTimeout(() => {
        btn.innerHTML = originalText
        btn.disabled = false
      }, 3000)
    } finally {
      btn.classList.remove('fang-action-loading')
    }
  })
}

// --- Auto-initialization ---

function initFangElements(root) {
  // Sortable tables
  root.querySelectorAll('[data-fang-table]').forEach(initSortableTable)

  // Action buttons
  root.querySelectorAll('[data-fang-action]').forEach(initActionButton)

  // Charts (initialized by widget JS, but handle standalone data-fang-chart too)
  root.querySelectorAll('[data-fang-chart]').forEach(el => {
    if (el._fangChart) return
    try {
      const config = JSON.parse(el.dataset.fangChart)
      const canvas = el.querySelector('canvas') || el
      if (canvas.tagName === 'CANVAS') {
        el._fangChart = Fang.renderChart(canvas, config)
      }
    } catch (err) {
      console.error('[Fang] Chart auto-init failed:', err)
    }
  })
}

// Init on page load
document.addEventListener('DOMContentLoaded', () => initFangElements(document))

// MutationObserver for Turbo Stream inserts
const fangObserver = new MutationObserver((mutations) => {
  for (const mutation of mutations) {
    for (const node of mutation.addedNodes) {
      if (node.nodeType === Node.ELEMENT_NODE) {
        initFangElements(node)
      }
    }
  }
})
fangObserver.observe(document.body, { childList: true, subtree: true })
