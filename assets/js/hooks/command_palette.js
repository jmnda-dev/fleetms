// Client-side behaviour for the global search (⌘K) palette. Opening, closing
// and arrow-key navigation happen entirely in the browser — the LiveComponent
// only runs the search when the user types.
export default {
  mounted() {
    this.input = this.el.querySelector("[data-cmdk-input]")
    this.active = -1

    this.onWindowKeydown = (e) => {
      const key = e.key.toLowerCase()
      if ((e.metaKey || e.ctrlKey) && key === "k") {
        e.preventDefault()
        this.toggle()
      }
    }
    window.addEventListener("keydown", this.onWindowKeydown)

    this.openers = Array.from(document.querySelectorAll("[data-cmdk-open]"))
    this.onOpenerClick = () => this.open()
    this.openers.forEach((b) => b.addEventListener("click", this.onOpenerClick))

    this.el.addEventListener("keydown", (e) => this.handleNav(e))
    this.el
      .querySelector("[data-cmdk-backdrop]")
      ?.addEventListener("click", () => this.close())

    // Results re-render as the user types; keep the highlight in range.
    this.el.addEventListener("phx:update", () => this.clampActive())
  },

  isOpen() {
    return !this.el.classList.contains("hidden")
  },

  toggle() {
    this.isOpen() ? this.close() : this.open()
  },

  open() {
    this.el.classList.remove("hidden")
    document.body.classList.add("overflow-hidden")
    this.active = -1
    requestAnimationFrame(() => {
      this.input?.focus()
      this.input?.select()
    })
  },

  close() {
    this.el.classList.add("hidden")
    document.body.classList.remove("overflow-hidden")
    this.clearHighlight()
  },

  results() {
    return Array.from(this.el.querySelectorAll("[data-cmdk-result]"))
  },

  clearHighlight() {
    this.results().forEach((r) => r.removeAttribute("aria-selected"))
  },

  clampActive() {
    if (this.active >= this.results().length) this.active = -1
  },

  highlight(idx) {
    const items = this.results()
    if (items.length === 0) return
    this.active = ((idx % items.length) + items.length) % items.length
    items.forEach((r, i) =>
      i === this.active
        ? r.setAttribute("aria-selected", "true")
        : r.removeAttribute("aria-selected")
    )
    items[this.active].scrollIntoView({ block: "nearest" })
  },

  handleNav(e) {
    if (e.key === "Escape") {
      e.preventDefault()
      this.close()
    } else if (e.key === "ArrowDown") {
      e.preventDefault()
      this.highlight(this.active + 1)
    } else if (e.key === "ArrowUp") {
      e.preventDefault()
      this.highlight(this.active - 1)
    } else if (e.key === "Enter") {
      const items = this.results()
      const target = items[this.active] || items[0]
      if (target) {
        e.preventDefault()
        target.click()
      }
    }
  },

  destroyed() {
    window.removeEventListener("keydown", this.onWindowKeydown)
    this.openers?.forEach((b) => b.removeEventListener("click", this.onOpenerClick))
    document.body.classList.remove("overflow-hidden")
  },
}
