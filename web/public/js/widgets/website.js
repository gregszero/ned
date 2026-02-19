registerWidget('website', {
  init(el, metadata) {
    const content = el.querySelector('.canvas-component-content')
    const emptyState = content?.querySelector('[data-website-empty]')
    if (!emptyState) return // Already has content

    // Build setup form
    const form = document.createElement('div')
    form.className = 'flex flex-col gap-2 p-1'
    form.innerHTML = `
      <input type="url" placeholder="https://example.com" class="text-xs" style="padding:0.375rem 0.5rem" data-website-url>
      <div class="flex gap-2 items-center">
        <label class="flex items-center gap-1 text-xs cursor-pointer" style="color:var(--muted-foreground)">
          <input type="radio" name="mode-${el.dataset.componentId}" value="snippet" checked style="width:auto;accent-color:var(--primary)"> Snippet
        </label>
        <label class="flex items-center gap-1 text-xs cursor-pointer" style="color:var(--muted-foreground)">
          <input type="radio" name="mode-${el.dataset.componentId}" value="iframe" style="width:auto;accent-color:var(--primary)"> iFrame
        </label>
      </div>
      <textarea placeholder="What to extract? e.g. Show the top 5 headlines" class="text-xs" rows="2" style="padding:0.375rem 0.5rem;resize:none" data-website-desc></textarea>
      <button class="xs" type="button" data-website-submit>Add</button>
    `

    // Toggle description field visibility based on mode
    const radios = form.querySelectorAll('input[type="radio"]')
    const descField = form.querySelector('[data-website-desc]')
    radios.forEach(r => r.addEventListener('change', () => {
      descField.style.display = r.value === 'iframe' && r.checked ? 'none' : ''
    }))

    // Submit handler
    form.querySelector('[data-website-submit]').addEventListener('click', async () => {
      const url = form.querySelector('[data-website-url]').value.trim()
      if (!url) return
      const mode = form.querySelector(`input[name="mode-${el.dataset.componentId}"]:checked`).value
      const description = descField.value.trim()

      const pageId = el.closest('[data-page-id]')?.dataset.pageId ||
                     el.closest('.conversation-canvas')?.dataset.canvasControllerPageIdValue
      const compId = el.dataset.componentId
      if (!pageId || !compId) return

      const meta = { ...metadata, url, mode, description }

      try {
        await fetch(`/api/pages/${pageId}/components/${compId}`, {
          method: 'PATCH',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ metadata: meta })
        })

        // If snippet mode and has description, send to AI for extraction code
        if (mode === 'snippet' && description) {
          const msg = `Generate Ruby extraction code for the website widget. URL: ${url}\nDescription: ${description}\n\nThe code should work with a Nokogiri doc variable and return an HTML string. Use doc.css() or doc.xpath() to extract content. Return only the Ruby code, no explanation.`
          // Create a conversation to generate extraction code
          const convResp = await fetch('/api/conversations', {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: `ai_page_id=${pageId}&title=Website+extraction:+${encodeURIComponent(url)}`
          })
          const conv = await convResp.json()
          await fetch(`/api/conversations/${conv.id}/messages`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
            body: `content=${encodeURIComponent(msg)}`
          })
        }

        // Reload component
        if (mode === 'iframe') {
          content.innerHTML = `<div style="height:100%;min-height:300px"><iframe src="${url}" style="width:100%;height:100%;border:none;border-radius:0 0 var(--radius-lg) var(--radius-lg)" sandbox="allow-scripts allow-same-origin allow-forms allow-popups"></iframe></div>`
        } else {
          content.innerHTML = `<div class="flex flex-col gap-2 p-2"><div class="text-xs" style="color:var(--muted-foreground)">Generating extraction code...</div><a href="${url}" target="_blank" rel="noopener" class="text-xs" style="color:var(--muted-foreground)">${url}</a></div>`
        }
      } catch (e) {
        console.error('[Website] Failed to save:', e)
      }
    })

    emptyState.replaceWith(form)
  },

  destroy(el) {
    // Nothing to clean up
  }
})
