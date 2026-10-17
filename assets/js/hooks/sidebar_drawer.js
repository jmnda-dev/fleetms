// Controls the mobile sidebar drawer with a single Flowbite Drawer instance.
//
// Same reason as filter_drawer.js: Flowbite's Phoenix build re-runs `initDrawers`
// on window.load AND every `phx:page-loading-stop`, binding a fresh toggle handler
// each time without removing the old one. With the sidebar wired via Flowbite's
// `data-drawer-*` auto-init, each navigation added another backdrop, so closing
// (tap-away) removed only the newest one and left the others hanging over the page.
//
// Managing one Drawer here — with the trigger's `data-drawer-*` attributes removed
// so Flowbite's auto-init skips it — guarantees exactly one backdrop. `inert` and
// `aria-hidden` on the sidebar are handled by layout.js (viewport-aware), which
// reacts to the translate class this Drawer toggles.
const BACKDROP = "bg-dark-backdrop/70 fixed inset-0 z-30"

const SidebarDrawer = {
  mounted() {
    this.panel = document.getElementById(this.el.getAttribute("aria-controls"))
    if (!this.panel || !window.Drawer) return

    this.drawer = new window.Drawer(this.panel, {backdropClasses: BACKDROP, placement: "left"})

    this.toggle = (e) => {
      e.preventDefault()
      this.drawer.toggle()
    }
    this.el.addEventListener("click", this.toggle)

    // Tapping a nav link navigates; close the drawer so it doesn't stay open over
    // the new page on mobile.
    this.onPanelClick = (e) => {
      if (e.target.closest("a")) this.drawer.hide()
    }
    this.panel.addEventListener("click", this.onPanelClick)
  },

  destroyed() {
    this.el.removeEventListener("click", this.toggle)
    if (this.panel && this.onPanelClick) this.panel.removeEventListener("click", this.onPanelClick)
    // Drop this instance's backdrop so nothing lingers after navigation.
    if (this.drawer) this.drawer.hide()
  },
}

export default SidebarDrawer
