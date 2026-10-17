import {mount, unmount} from "svelte"
import InspectionBuilder from "../../svelte/InspectionBuilder.svelte"

// Mounts the Svelte form-builder island inside a LiveView-owned element and
// bridges it to the server: the initial document is read from `data-schema`, and
// the whole edited document is pushed back via the "save_schema" event on save.
// The container must use `phx-update="ignore"` so LiveView leaves Svelte's DOM
// alone.
const InspectionBuilderHook = {
  mounted() {
    const schema = JSON.parse(this.el.dataset.schema || "{}")
    const users = JSON.parse(this.el.dataset.users || "[]")
    const roles = JSON.parse(this.el.dataset.roles || "[]")

    this.island = mount(InspectionBuilder, {
      target: this.el,
      props: {
        schema,
        users,
        roles,
        onSave: (doc) => this.pushEvent("save_schema", {schema: doc})
      }
    })
  },

  destroyed() {
    if (this.island) unmount(this.island)
  }
}

export default InspectionBuilderHook
