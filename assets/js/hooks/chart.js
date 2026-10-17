import {mount, unmount} from "svelte"
import Chart from "../../svelte/Chart.svelte"

// Mounts the Svelte `Chart` island inside a LiveView-owned element. The chart spec is
// read from `data-spec` (JSON); the island is re-mounted when that spec changes (e.g. a
// future date-range filter) or when the app's dark mode is toggled. The container must
// use `phx-update="ignore"` so LiveView leaves ECharts' canvas alone.
const isDark = () => document.documentElement.classList.contains("dark")

const ChartHook = {
  mounted() {
    this.render()

    // Re-theme when the `dark` class flips on <html>.
    this.observer = new MutationObserver(() => {
      if (this.dark !== isDark()) this.render()
    })
    this.observer.observe(document.documentElement, {
      attributes: true,
      attributeFilter: ["class"],
    })
  },

  updated() {
    this.render()
  },

  destroyed() {
    this.observer?.disconnect()
    if (this.island) unmount(this.island)
  },

  render() {
    const spec = JSON.parse(this.el.dataset.spec || "{}")
    this.dark = isDark()

    if (this.island) unmount(this.island)
    this.el.innerHTML = ""
    this.island = mount(Chart, {target: this.el, props: {spec, dark: this.dark}})
  },
}

export default ChartHook
