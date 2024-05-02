import darkModeToggleJs from "./dark-mode.js"
import sidebarInitJs from "./sidebar.js"
import {humanizeString} from "./utils.js"

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

Hooks.HumanizeText = {
  mounted() {
    const string = this.el.textContent

    if (string) {
      this.el.textContent = humanizeString(string)
    }
  }
}
export default Hooks
