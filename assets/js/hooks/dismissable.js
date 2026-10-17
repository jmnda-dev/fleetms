// Hides an element the viewer has dismissed, remembering the choice in
// localStorage per `data-key`. The element stays in the server-rendered markup
// (so it reappears if the user clears storage or the underlying reason is still
// true after a redeploy) but is hidden immediately on mount when already
// dismissed. A `[data-dismiss]` button inside marks it dismissed.
export default {
  mounted() {
    this.key = this.el.dataset.key
    if (this.key && this.stored(this.key)) {
      this.el.hidden = true
      return
    }
    this.el.querySelector("[data-dismiss]")?.addEventListener("click", () => {
      if (this.key) this.store(this.key)
      this.el.hidden = true
    })
  },

  stored(key) {
    try {
      return localStorage.getItem(key) === "1"
    } catch (_e) {
      return false
    }
  },

  store(key) {
    try {
      localStorage.setItem(key, "1")
    } catch (_e) {
      // storage unavailable (private window, blocked) — dismissal is per-view only
    }
  },
}
