import darkModeToggleJs from "./dark-mode.js"
import sidebarInitJs from "./sidebar.js"

Hooks = {}
Hooks.initDarkModeToggle = {
  mounted() {
    darkModeToggleJs()
  }
}

Hooks.initSidebarJs = {
  mounted() {
    sidebarInitJs()
  },
  updated() {
    this.mounted()
  }
}

export default Hooks
