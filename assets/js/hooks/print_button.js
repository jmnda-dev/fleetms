// Triggers the browser's print dialog when the element is clicked. Used by the
// work-order document view's "Print" button (CSP-safe, no inline handler).
export default {
  mounted() {
    this.handleClick = () => window.print()
    this.el.addEventListener("click", this.handleClick)
  },
  destroyed() {
    this.el.removeEventListener("click", this.handleClick)
  },
}
