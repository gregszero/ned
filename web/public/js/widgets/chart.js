registerWidget('chart', {
  init(el, metadata) {
    const chartContainer = el.querySelector('[data-fang-chart]')
    if (!chartContainer) return

    const canvas = chartContainer.querySelector('canvas')
    if (!canvas) return

    try {
      const config = JSON.parse(chartContainer.dataset.fangChart)
      el._chartInstance = Fang.renderChart(canvas, config)
    } catch (e) {
      console.error('[Chart Widget] Init failed:', e)
    }
  },

  destroy(el) {
    if (el._chartInstance) {
      el._chartInstance.destroy()
      delete el._chartInstance
    }
  }
})
