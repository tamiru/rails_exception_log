import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tabs", "tabContent", "backtraceContent", "backtraceHidden", "sourcePanel"]

  // ─── Tab Switching ────────────────────────────────────────

  // Reopen the tab named in the URL (#backtrace), so a reload, a shared
  // link, or Back from another page lands on the same tab.
  connect() {
    const tabName = decodeURIComponent(window.location.hash.slice(1))
    if (tabName && this.hasTab(tabName)) this.showTab(tabName)
  }

  switchTab(event) {
    const tabName = event.params.tab || event.currentTarget.getAttribute("data-rn-tab-param")
    if (!tabName) return

    this.showTab(tabName)
    const url = new URL(window.location.href)
    url.hash = tabName === "overview" ? "" : tabName
    history.replaceState(history.state, "", url)
  }

  /** Ignores a hash that names no tab on this exception (tabs vary by data). */
  hasTab(tabName) {
    return this.tabContentTargets.some(content => content.getAttribute("data-rn-tab-content") === tabName)
  }

  /** One place that keeps the tab buttons, their ARIA state and the panels in step. */
  showTab(tabName) {
    if (this.hasTabsTarget) {
      this.tabsTarget.querySelectorAll(".rn-tab").forEach(tab => {
        const isActive = tab.getAttribute("data-rn-tab-param") === tabName
        tab.classList.toggle("active", isActive)
        tab.setAttribute("aria-selected", isActive ? "true" : "false")
      })
    }

    this.tabContentTargets.forEach(content => {
      const isTarget = content.getAttribute("data-rn-tab-content") === tabName
      content.style.display = isTarget ? "" : "none"
    })
  }

  // ─── Copy to Clipboard ───────────────────────────────────

  copyId(event) {
    const id = event.currentTarget.getAttribute("data-rails_exception_log-detail-id-value") ||
               event.currentTarget.dataset.rails_exception_logDetailIdValue
    if (id) this.copyToClipboard(id, event.currentTarget)
  }

  copyMessage(event) {
    const msg = event.currentTarget.getAttribute("data-rails_exception_log-detail-message-value") ||
                event.currentTarget.dataset.rails_exception_logDetailMessageValue
    if (msg) this.copyToClipboard(msg, event.currentTarget)
  }

  copyBacktrace(event) {
    const bt = event.currentTarget.getAttribute("data-rails_exception_log-detail-backtrace-value") ||
               event.currentTarget.dataset.rails_exception_logDetailBacktraceValue
    if (bt) this.copyToClipboard(bt, event.currentTarget)
  }

  async copyToClipboard(text, button) {
    try {
      await navigator.clipboard.writeText(text)
    } catch {
      const textarea = document.createElement("textarea")
      textarea.value = text
      textarea.style.position = "fixed"
      textarea.style.opacity = "0"
      document.body.appendChild(textarea)
      textarea.select()
      document.execCommand("copy")
      document.body.removeChild(textarea)
    }
    const orig = button.innerHTML
    button.classList.add("copied")
    button.innerHTML = `<svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" /></svg> Copied!`
    setTimeout(() => { button.classList.remove("copied"); button.innerHTML = orig }, 2000)
  }

  // ─── Backtrace Expand ────────────────────────────────────

  expandBacktrace(event) {
    event.preventDefault()
    const hidden = this.backtraceHiddenTarget
    if (hidden) {
      hidden.style.display = hidden.style.display === "none" ? "" : "none"
      event.currentTarget.textContent = hidden.style.display === "none"
        ? "Show more frames"
        : "Hide additional frames"
    }
  }

  // ─── Source Code Toggle ─────────────────────────────────

  toggleSource(event) {
    event.preventDefault()
    const btn = event.currentTarget
    const file = btn.dataset.file
    const line = btn.dataset.line

    // Find the source panel for this frame
    const panel = this.sourcePanelTargets.find(p =>
      p.dataset.file === file && p.dataset.line === line
    )
    if (!panel) return

    if (panel.style.display === "none") {
      // Load source code via AJAX
      panel.style.display = ""
      const loading = panel.querySelector(".rn-source-loading")
      if (loading) loading.style.display = ""

      fetch(`/rails_exception_log/source_code?file=${encodeURIComponent(file)}&line=${line}&context=5`, {
        headers: { "Accept": "application/json" }
      })
        .then(r => r.json())
        .then(data => {
          if (data.source) {
            panel.innerHTML = this.renderSourceSnippet(data.source, data.blame)
          } else {
            panel.innerHTML = `<div class="text-xs" style="color: var(--rn-text-muted); padding: 0.5rem">Source not available</div>`
          }
        })
        .catch(() => {
          panel.innerHTML = `<div class="text-xs" style="color: var(--rn-text-muted); padding: 0.5rem">Failed to load source</div>`
        })
    } else {
      panel.style.display = "none"
    }
  }

  renderSourceSnippet(snippet, blame) {
    let html = `<div class="rn-source-code rounded" style="background: var(--rn-bg-primary); border: 1px solid var(--rn-border-light); overflow-x: auto; font-size: 0.75rem; font-family: monospace">`

    // Git blame header
    if (blame) {
      html += `<div class="flex items-center gap-2 px-3 py-1.5" style="background: var(--rn-bg-secondary); border-bottom: 1px solid var(--rn-border-light); font-size: 0.7rem; color: var(--rn-text-muted)">`
      html += `<span style="color: var(--rn-primary)">${blame.author || 'unknown'}</span>`
      html += `<span>·</span>`
      html += `<span>${blame.date || ''}</span>`
      html += `<span>·</span>`
      html += `<span style="color: var(--rn-text-muted)">${blame.message || ''}</span>`
      html += `<span class="ml-auto font-mono" style="color: var(--rn-text-muted)">${blame.sha || ''}</span>`
      html += `</div>`
    }

    // Source lines
    snippet.lines.forEach((line) => {
      const bg = line.is_error ? 'var(--rn-bg-warning-subtle)' : 'transparent'
      html += `<div class="flex" style="background: ${bg}; padding: 0 0.75rem">`
      html += `<span style="min-width: 2.5rem; text-align: right; color: var(--rn-text-muted); user-select: none; padding-right: 1rem">${line.number}</span>`
      html += `<span style="white-space: pre; color: var(--rn-text)">${(line.content || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')}</span>`
      html += `</div>`
    })

    html += `</div>`
    return html
  }
}
