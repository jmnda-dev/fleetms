import darkModeToggleJs from "./dark-mode.js"
import sidebarInitJs from "./sidebar.js"
import { humanizeString } from "./utils.js"

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
    this.el.querySelectorAll('[data-humanize]').forEach((element) => {
      text = element.textContent.trim();
      humanizedString = humanizedString(text)

      element.textContent = humanizedString;
    });
  },
  updated() {
    this.mounted()
  }
}

export default Hooks
