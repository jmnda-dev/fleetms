import TomSelect from "tom-select/dist/js/tom-select.complete.js"

// A single, generic hook that turns any <select> into a Tom Select widget.
// Everything is driven by data-* attributes set by the <.search_select>
// component, so there is exactly one hook for every select in the app.
//
// The widget lives inside a `phx-update="ignore"` wrapper, so LiveView never
// re-patches Tom Select's DOM after mount. State therefore can't be clobbered
// by server renders. We instead talk to the server explicitly:
//   * remote search  -> pushEvent(remote_event, {q})           (reply: options)
//   * dependent input -> pushEvent(dependent_event, {value})   (server pushes
//                        "tomselect:options:<target_id>" back to the target)
// and we sync the chosen value back into the form by dispatching a bubbling
// "input" event so phx-change / phx-submit see it.
const TomSelectHook = {
  mounted() {
    const el = this.el
    const ds = el.dataset
    const multiple = el.multiple

    const config = {
      plugins: {},
      create: ds.create === "true",
      createOnBlur: ds.create === "true",
      persist: false,
      placeholder: ds.placeholder || null,
      maxItems: multiple ? null : 1,
      hideSelected: multiple,
      closeAfterSelect: !multiple,
      allowEmptyOption: true
    }

    if (multiple) {
      config.plugins.remove_button = {title: ds.removeTitle || "Remove"}
    }

    // Rich mode: each <option> carries a `data-subtitle`; render the dropdown as a
    // two-line entry (title + muted subtitle). We build the option objects
    // explicitly so the subtitle rides along, and lean on Tom Select's own
    // `escape` in the render callbacks so user-entered text is never injected raw.
    if (ds.rich === "true") {
      config.valueField = "value"
      config.labelField = "text"
      config.searchField = ["text", "subtitle"]
      config.options = Array.from(el.options)
        .filter((o) => o.value !== "")
        .map((o) => ({value: o.value, text: o.text, subtitle: o.dataset.subtitle || ""}))
      config.items = Array.from(el.selectedOptions)
        .map((o) => o.value)
        .filter((v) => v !== "")
      config.render = {
        option: (data, escape) =>
          `<div class="ts-rich-option">` +
          `<div class="ts-rich-title">${escape(data.text)}</div>` +
          (data.subtitle ? `<div class="ts-rich-sub">${escape(data.subtitle)}</div>` : "") +
          `</div>`,
        item: (data, escape) => `<div>${escape(data.text)}</div>`
      }
    }

    // Hybrid: only fetch from the server when a remote event is declared.
    // Otherwise Tom Select filters the static <option>s client-side.
    if (ds.remoteEvent) {
      config.load = (query, callback) => {
        this.pushEvent(ds.remoteEvent, {q: query}, (reply) => {
          callback((reply && reply.options) || [])
        })
      }
      config.shouldLoad = (query) => query.length > 0
    }

    this.ts = new TomSelect(el, config)

    // Honour an initial `disabled` on the underlying <select> (e.g. a dependent
    // select that stays off until its parent is chosen).
    if (el.disabled) this.ts.disable()

    this.ts.on("change", () => {
      // Let the LiveView form pick up the new value.
      el.dispatchEvent(new Event("input", {bubbles: true}))

      // Notify the server that a parent input changed so it can refresh any
      // dependent select (e.g. vehicle make -> model).
      if (ds.dependentEvent) {
        this.pushEvent(ds.dependentEvent, {value: this.ts.getValue()})
      }

      // Single-selects should stay closed after choosing a value. The `input`
      // above triggers a `phx-change` round-trip that refocuses the control and
      // re-opens the just-closed dropdown (most visible on the first selection).
      // Force it closed once that settles.
      if (!multiple) {
        setTimeout(() => {
          this.ts.close()
          this.ts.blur()
        }, 0)
      }
    })

    // This select can also BE a dependent target: the server addresses it by id
    // and pushes a fresh option set. Decoupled from whoever triggered it.
    this.handleEvent(`tomselect:options:${el.id}`, ({options, value, disabled}) => {
      this.ts.clear(true)
      this.ts.clearOptions()
      this.ts.addOptions(options || [])
      if (value != null && value !== "") this.ts.setValue(value, true)
      // Optionally toggle the control's enabled state (undefined = leave as-is).
      if (disabled === true) this.ts.disable()
      else if (disabled === false) this.ts.enable()
    })
  },

  destroyed() {
    if (this.ts) this.ts.destroy()
  }
}

export default TomSelectHook
