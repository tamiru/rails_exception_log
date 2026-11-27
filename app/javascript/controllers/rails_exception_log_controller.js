import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["activity", "shortcutsDialog", "tabs", "tabContent", "exceptionList", "backtraceHidden", "backtraceContent"]
  static values = { shortcuts: Boolean }

  connect() {
    this.selectedIndex = -1
    this.rows = []

    this.showActivity = this.showActivity.bind(this)
    this.hideActivity = this.hideActivity.bind(this)

    document.addEventListener("turbo:before-fetch-request", this.showActivity)
    document.addEventListener("turbo:before-fetch-response", this.hideActivity)
    document.addEventListener("turbo:submit-end", this.hideActivity)

    if (this.shortcutsValue) {
      this.boundKeydown = this.handleKeydown.bind(this)
      document.addEventListener("keydown", this.boundKeydown)
    }
  }

  disconnect() {
    document.removeEventListener("turbo:before-fetch-request", this.showActivity)
    document.removeEventListener("turbo:before-fetch-response", this.hideActivity)
    document.removeEventListener("turbo:submit-end", this.hideActivity)

    if (this.boundKeydown) {
      document.removeEventListener("keydown", this.boundKeydown)
    }
  }

  // ─── Keyboard Navigation ──────────────────────────────────

  handleKeydown(event) {
    // Ignore when typing in an input/textarea/select
    const tag = event.target.tagName.toLowerCase()
    if (tag === "input" || tag === "textarea" || tag === "select") {
      if (event.key === "Escape") {
        event.target.blur()
        event.preventDefault()
      }
      return
    }

    switch (event.key) {
      case "/":
        event.preventDefault()
        this.focusSearch()
        break
      case "j":
      case "ArrowDown":
        event.preventDefault()
        this.navigateDown()
        break
      case "k":
      case "ArrowUp":
        event.preventDefault()
        this.navigateUp()
        break
      case "Enter":
        event.preventDefault()
        this.openSelected()
        break
      case "p":
      case "ArrowLeft":
        event.preventDefault()
        this.navigateToPrev()
        break
      case "n":
      case "ArrowRight":
        event.preventDefault()
        this.navigateToNext()
        break
      case "t":
        event.preventDefault()
        this.toggleTheme()
        break
      case "Escape":
        event.preventDefault()
        if (this.shortcutsOpen()) {
          this.closeShortcuts()
        } else {
          this.leaveDetails()
        }
        break
      case "?":
        event.preventDefault()
        this.toggleShortcuts()
        break
      case "1": case "2": case "3": case "4": case "5":
      case "6": case "7": case "8": case "9":
        event.preventDefault()
        this.switchTabByIndex(parseInt(event.key) - 1)
        break
    }
  }

  focusSearch() {
    const search = this.element.querySelector(".rn-search .rn-input, input[type='search']")
    if (search) {
      search.focus()
      search.select()
    }
  }

  refreshRows() {
    if (this.hasExceptionListTarget) {
      this.rows = Array.from(this.exceptionListTarget.querySelectorAll("tr[data-url]"))
    } else {
      this.rows = Array.from(this.element.querySelectorAll("tr[data-url]"))
    }
  }

  navigateDown() {
    this.refreshRows()
    if (this.rows.length === 0) return

    this.selectedIndex = Math.min(this.selectedIndex + 1, this.rows.length - 1)
    this.highlightRow()
  }

  navigateUp() {
    this.refreshRows()
    if (this.rows.length === 0) return

    this.selectedIndex = Math.max(this.selectedIndex - 1, 0)
    this.highlightRow()
  }

  highlightRow() {
    this.rows.forEach((row, i) => {
      row.classList.toggle("selected", i === this.selectedIndex)
    })

    const row = this.rows[this.selectedIndex]
    if (row) {
      row.scrollIntoView({ block: "nearest", behavior: "smooth" })
    }
  }

  openSelected() {
    this.refreshRows()
    if (this.selectedIndex < 0 || this.selectedIndex >= this.rows.length) return

    const url = this.rows[this.selectedIndex].dataset.url
    if (url) this.visit(url)
  }

  // ─── Row Selection ────────────────────────────────────────

  /**
   * Opens the clicked row's exception on its own detail page. Clicks on a
   * link or button inside the row are left to that control, and a modifier
   * click opens the page in a new tab, as it would for a plain link.
   */
  selectRow(event) {
    if (event.target?.closest?.("a, button, input, select, textarea, label")) return

    const url = event.currentTarget.dataset.url
    if (!url) return

    event.preventDefault()
    if (event.metaKey || event.ctrlKey || event.button === 1) {
      window.open(url, "_blank", "noopener")
    } else {
      this.visit(url)
    }
  }

  visit(url) {
    if (window.Turbo?.visit) {
      window.Turbo.visit(url)
    } else {
      window.location.assign(url)
    }
  }

  stopPropagation(event) {
    event.stopPropagation()
  }

  // ─── Leaving the Detail Page ──────────────────────────────

  /**
   * Esc goes back to the (filtered) list from a detail page; on the list
   * itself it clears the keyboard selection.
   */
  leaveDetails() {
    const back = this.element.querySelector("[data-rn-nav='back']")
    if (back) {
      back.click()
      return
    }

    this.refreshRows()
    this.rows.forEach(r => r.classList.remove("selected"))
    this.selectedIndex = -1
  }

  // ─── Tab Switching ────────────────────────────────────────

  switchTab(event) {
    const tabName = event.currentTarget.dataset.flTabParam || event.currentTarget.dataset.flTab
    this.activateTab(tabName)
  }

  // The tabs belong to the detail controller; clicking keeps both in step.
  switchTabByIndex(index) {
    const tabs = this.element.querySelectorAll(".rn-tabs .rn-tab")
    if (index >= 0 && index < tabs.length) tabs[index].click()
  }

  activateTab(tabName) {
    // Update tab buttons
    if (this.hasTabsTarget) {
      this.tabsTarget.querySelectorAll(".rn-tab").forEach(tab => {
        const isActive = (tab.dataset.flTabParam || tab.dataset.flTab) === tabName
        tab.classList.toggle("active", isActive)
      })
    }

    // Show/hide tab content
    this.tabContentTargets.forEach(content => {
      const isTarget = content.dataset.flTabContent === tabName
      content.style.display = isTarget ? "" : "none"
    })
  }

  // ─── Theme Toggle ─────────────────────────────────────────

  toggleTheme() {
    const themeController = this.application.getControllerForElementAndIdentifier(
      document.documentElement,
      "rails_exception_log-theme"
    )
    if (themeController) {
      themeController.toggle()
    } else {
      // Fallback: direct DOM manipulation
      const root = document.documentElement
      const isDark = root.classList.contains("dark")
      root.classList.remove("dark", "light")
      root.classList.add(isDark ? "light" : "dark")
      localStorage.setItem("rails_exception_log-theme", isDark ? "light" : "dark")
    }
  }

  // ─── Keyboard Shortcuts Dialog ────────────────────────────

  shortcutsOpen() {
    return this.hasShortcutsDialogTarget && this.shortcutsDialogTarget.classList.contains("open")
  }

  toggleShortcuts() {
    if (!this.hasShortcutsDialogTarget) return
    const isOpen = this.shortcutsDialogTarget.classList.contains("open")
    if (isOpen) {
      this.closeShortcuts()
    } else {
      this.shortcutsDialogTarget.classList.add("open")
      document.getElementById("rn-shortcuts-button")?.setAttribute("aria-expanded", "true")
    }
  }

  closeShortcuts() {
    if (this.hasShortcutsDialogTarget) {
      this.shortcutsDialogTarget.classList.remove("open")
      document.getElementById("rn-shortcuts-button")?.setAttribute("aria-expanded", "false")
    }
  }

  // ─── Navigation (prev/next) ───────────────────────────────

  navigateToPrev() {
    this.element.querySelector("[data-rn-nav='prev']")?.click()
  }

  navigateToNext() {
    this.element.querySelector("[data-rn-nav='next']")?.click()
  }

  // ─── Copy to Clipboard ───────────────────────────────────

  copyId(event) {
    const id = event.currentTarget.dataset.rails_exception_logIdValue
    if (id) this.copyToClipboard(id, event.currentTarget)
  }

  copyMessage(event) {
    const message = event.currentTarget.dataset.rails_exception_logMessageValue
    if (message) this.copyToClipboard(message, event.currentTarget)
  }

  copyBacktrace(event) {
    const backtrace = event.currentTarget.dataset.rails_exception_logBacktraceValue
    if (backtrace) this.copyToClipboard(backtrace, event.currentTarget)
  }

  async copyToClipboard(text, button) {
    try {
      await navigator.clipboard.writeText(text)
      const originalHTML = button.innerHTML
      button.classList.add("copied")
      button.innerHTML = `<svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" /></svg> Copied!`
      setTimeout(() => {
        button.classList.remove("copied")
        button.innerHTML = originalHTML
      }, 2000)
    } catch (err) {
      // Fallback for older browsers
      const textarea = document.createElement("textarea")
      textarea.value = text
      textarea.style.position = "fixed"
      textarea.style.opacity = "0"
      document.body.appendChild(textarea)
      textarea.select()
      document.execCommand("copy")
      document.body.removeChild(textarea)
    }
  }

  // ─── Backtrace Expand ─────────────────────────────────────

  expandBacktrace(event) {
    event.preventDefault()
    const hidden = this.backtraceHiddenTarget
    if (hidden) {
      hidden.style.display = hidden.style.display === "none" ? "" : "none"
      event.currentTarget.textContent = hidden.style.display === "none"
        ? `Show ${hidden.textContent.split("\n").length} more frames`
        : "Hide additional frames"
    }
  }

  // ─── Submit Helpers ───────────────────────────────────────

  submit() {
    this.showActivity()
    const form = this.element.querySelector("form[data-turbo-frame]")
    if (form) form.requestSubmit()
  }

  debouncedSubmit(event) {
    clearTimeout(this._debounceTimer)
    this._debounceTimer = setTimeout(() => {
      this.submit()
    }, 400)
  }

  // ─── Loading State ────────────────────────────────────────

  showActivity() {
    if (!this.hasActivityTarget) return
    this.activityTarget.hidden = false
    this.activityTarget.classList.remove("hidden")
  }

  hideActivity() {
    if (!this.hasActivityTarget) return
    this.activityTarget.hidden = true
    this.activityTarget.classList.add("hidden")
  }
}
