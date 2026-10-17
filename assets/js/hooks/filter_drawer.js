// Owns a single Flowbite Drawer for a filter panel, wired to the trigger the hook
// is attached to (via `aria-controls`) and any `[data-drawer-close]` elements
// inside the panel.
//
// Why a hook instead of Flowbite's `data-drawer-*` auto-wiring: Flowbite's Phoenix
// build re-runs its init on BOTH `window.load` AND every `phx:page-loading-stop`,
// and its `initDrawers` binds a fresh click handler each time without removing the
// old ones. On a hard page load both fire, so the trigger ends up with two show
// handlers → two stacked backdrops (visibly too dark). Managing one Drawer
// instance here — and keeping the panel out of Flowbite's auto-init scope (no
// `data-drawer-*` attributes) — guarantees exactly one backdrop.
const BACKDROP = "bg-dark-backdrop/70 fixed inset-0 z-30"

const FilterDrawer = {
  mounted() {
    const panel = document.getElementById(this.el.getAttribute("aria-controls"))
    if (!panel || !window.Drawer) return

    // Keep the closed off-canvas panel out of the tab order (its inputs are
    // focusable but hidden, which fails a11y). `inert` follows the open state.
    this.drawer = new window.Drawer(panel, {
      backdropClasses: BACKDROP,
      onShow: () => (panel.inert = false),
      onHide: () => (panel.inert = true),
    })
    panel.inert = true

    this.toggle = (e) => {
      e.preventDefault()
      this.drawer.toggle()
    }
    this.hide = () => this.drawer.hide()

    this.el.addEventListener("click", this.toggle)
    this.closers = Array.from(panel.querySelectorAll("[data-drawer-close]"))
    this.closers.forEach((c) => c.addEventListener("click", this.hide))
  },

  destroyed() {
    this.el.removeEventListener("click", this.toggle)
    if (this.closers) this.closers.forEach((c) => c.removeEventListener("click", this.hide))
    // Removes the instance's backdrop so nothing lingers after navigation.
    if (this.drawer) this.drawer.hide()
  },
}

export default FilterDrawer
