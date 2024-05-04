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
    document.querySelectorAll('[data-humanize]').forEach((element) => {
      let text = element.textContent.trim();

      if (text) {
        let humanizedText = humanizeString(text);
        element.textContent = humanizedText;
      }
    });
  }
}
export default Hooks
