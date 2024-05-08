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
      humanizedString = humanizeString(text)

      element.textContent = humanizedString;
    });
  },
  updated() {
    this.mounted()
  }
}
Hooks.FormatDateAndTime = {
  mounted() {
    this.updated();
  },
  updated() {
    textContent = this.el.textContent.trim();
    excludeTime = this.el.getAttribute('data-exclude-time')

    console.log(excludeTime)
    if (textContent) {
      let dt = new Date(textContent);
      if (excludeTime) {
        this.el.textContent = dt.toDateString()
      } else {
        this.el.textContent = dt.toDateString() + " " + dt.toLocaleTimeString();
      }
    } else {
      this.el.innerHTML = "--";
    }
    this.el.classList.remove("invisible");
  }
}
export default Hooks
