// Per-viewer "saved views" for a list page: remembers named query strings
// (search + filters + sort) in localStorage and re-applies them by navigating.
//
// The whole control is rendered client-side inside a `phx-update="ignore"`
// container so LiveView never clobbers it. Views are keyed by the page's
// `data-view-key`, so each list keeps its own set and they're shared across the
// orgs a user belongs to (the query string is org-agnostic; the path isn't, so
// applying builds `currentPath + storedQuery`).
export default {
  mounted() {
    this.key = "saved-views:" + (this.el.dataset.viewKey || location.pathname)
    this.menu = this.el.querySelector("[data-sv-menu]")
    this.list = this.el.querySelector("[data-sv-list]")
    this.toggle = this.el.querySelector("[data-sv-toggle]")
    this.saveBtn = this.el.querySelector("[data-sv-save]")

    this.onToggle = () => this.menu.classList.toggle("hidden")
    this.toggle.addEventListener("click", this.onToggle)

    this.onDocClick = (e) => {
      if (!this.el.contains(e.target)) this.menu.classList.add("hidden")
    }
    document.addEventListener("click", this.onDocClick)

    this.saveBtn.addEventListener("click", () => this.save())
    this.render()
  },

  read() {
    try {
      return JSON.parse(localStorage.getItem(this.key)) || []
    } catch (_e) {
      return []
    }
  },

  write(views) {
    try {
      localStorage.setItem(this.key, JSON.stringify(views))
    } catch (_e) {
      // storage unavailable — views are per-session only
    }
  },

  save() {
    const name = (window.prompt(this.el.dataset.savePrompt || "Name this view") || "").trim()
    if (!name) return
    const query = location.search // includes leading "?" or is ""
    const views = this.read().filter((v) => v.name !== name)
    views.push({ name, query })
    this.write(views)
    this.render()
  },

  remove(name) {
    this.write(this.read().filter((v) => v.name !== name))
    this.render()
  },

  render() {
    const views = this.read()
    this.list.replaceChildren()

    if (views.length === 0) {
      const empty = document.createElement("p")
      empty.className = "px-3 py-2 text-xs text-gray-400"
      empty.textContent = this.el.dataset.emptyText || "No saved views yet"
      this.list.appendChild(empty)
      return
    }

    for (const view of views) {
      const row = document.createElement("div")
      row.className =
        "flex items-center justify-between gap-2 px-3 py-1.5 text-sm hover:bg-gray-50 dark:hover:bg-gray-700"

      const link = document.createElement("a")
      link.href = location.pathname + view.query
      link.className = "min-w-0 flex-1 truncate text-heading"
      link.textContent = view.name
      row.appendChild(link)

      const del = document.createElement("button")
      del.type = "button"
      del.className = "shrink-0 text-gray-400 hover:text-fg-danger"
      del.setAttribute("aria-label", "Delete view")
      del.textContent = "✕"
      del.addEventListener("click", (e) => {
        e.preventDefault()
        this.remove(view.name)
      })
      row.appendChild(del)

      this.list.appendChild(row)
    }
  },

  destroyed() {
    this.toggle?.removeEventListener("click", this.onToggle)
    document.removeEventListener("click", this.onDocClick)
  },
}
