import {Datepicker} from "flowbite"

// Flowbite Datepicker wrapped for LiveView.
//
// Like the Tom Select hook, the widget owns its DOM: the host <input> lives
// inside a `phx-update="ignore"` container so morphdom never clobbers the value
// or the calendar Flowbite injects. When a date is picked, Flowbite fires a
// "changeDate" event on the input; we mirror that to a bubbling "input" event so
// the surrounding form's `phx-change`/`phx-submit` observe the new value.
//
// All config is read from `data-*` so the same hook serves every date field:
//   data-format    — display/parse format (default "yyyy-mm-dd", what the
//                    server expects for an Ecto/Ash :date)
//   data-min-date  — optional lower bound
//   data-max-date  — optional upper bound
//   data-autohide  — "false" to keep the calendar open after a pick
const DatePicker = {
  mounted() {
    const el = this.el
    const ds = el.dataset

    const options = {
      format: ds.format || "yyyy-mm-dd",
      autohide: ds.autohide !== "false",
      autoSelectToday: false,
      buttons: true,
      todayBtn: true,
      clearBtn: true
    }
    if (ds.minDate) options.minDate = ds.minDate
    if (ds.maxDate) options.maxDate = ds.maxDate

    this.datepicker = new Datepicker(el, options)

    this.onChange = () => el.dispatchEvent(new Event("input", {bubbles: true}))
    el.addEventListener("changeDate", this.onChange)
  },

  destroyed() {
    if (this.onChange) this.el.removeEventListener("changeDate", this.onChange)
    if (this.datepicker) this.datepicker.destroy()
  }
}

export default DatePicker
