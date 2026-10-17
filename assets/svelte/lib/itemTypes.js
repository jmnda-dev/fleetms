// The catalog of inspection item types. Drives the add-item menu, the default
// config each new item starts with, and type labels used across the builder.
//
// This mirrors the Ash union variants in `Fleetms.Inspections.Schema.*Config`
// (server-side source of truth) — the defaults here match those resources'
// attribute defaults so a freshly added item is already valid. Keep in sync when
// the server variants change.

export const EVENT_RULES = [
  {value: "never", label: "Never"},
  {value: "pass", label: "On pass"},
  {value: "fail", label: "On fail"},
  {value: "always", label: "Always"}
]

export const ITEM_TYPES = [
  {type: "pass_fail", label: "Pass / Fail", icon: "fa-circle-check", group: "Checks"},
  {type: "single_select", label: "Single select", icon: "fa-list-ul", group: "Checks"},
  {type: "multi_select", label: "Multi select", icon: "fa-list-check", group: "Checks"},
  {type: "number", label: "Number", icon: "fa-hashtag", group: "Measurements"},
  {type: "meter", label: "Meter / Odometer", icon: "fa-gauge", group: "Measurements"},
  {type: "date", label: "Date", icon: "fa-calendar", group: "Measurements"},
  {type: "text", label: "Text / Notes", icon: "fa-align-left", group: "Input"},
  {type: "photo", label: "Photo", icon: "fa-camera", group: "Input"},
  {type: "signature", label: "Signature", icon: "fa-signature", group: "Input"},
  {type: "instruction", label: "Instruction", icon: "fa-circle-info", group: "Display"}
]

export const TYPE_META = Object.fromEntries(ITEM_TYPES.map((t) => [t.type, t]))

export const GROUPS = [...new Set(ITEM_TYPES.map((t) => t.group))]

export function defaultConfig(type) {
  switch (type) {
    case "pass_fail":
      return {type, pass_label: "Pass", fail_label: "Fail", allow_na: true, comment_on: "never", photo_on: "never"}
    case "single_select":
      return {type, display: "dropdown", options: [], comment_on: "never", photo_on: "never"}
    case "multi_select":
      return {type, options: [], min_selected: 0, max_selected: null, fail_if_any_fail_option: true, comment_on: "never"}
    case "number":
      return {type, unit: "", decimals: 0, min: null, max: null, pass_min: null, pass_max: null, comment_on: "never", photo_on: "never"}
    case "meter":
      return {type, unit: "", write_to_vehicle: true, must_increase: true, comment_on: "never"}
    case "date":
      return {type, mode: "date", fail_if_past: false, fail_if_future: false}
    case "text":
      return {type, multiline: true, max_length: null}
    case "photo":
      return {type, min_photos: 1, max_photos: null}
    case "signature":
      return {type, prompt: "", who: "inspector"}
    case "instruction":
      return {type, body: ""}
    default:
      return {type: "pass_fail"}
  }
}

export function newItem(type) {
  return {id: uid(), label: "", help_text: "", required: false, visible_when: null, config: defaultConfig(type)}
}

export function newSection() {
  return {id: uid(), title: "Untitled section", description: "", visible_when: null, items: []}
}

export function newOption() {
  // The server attribute is `:fail?`, so the JSON key is the string "fail?".
  return {value: "", label: "", "fail?": false}
}

// Leaf comparison operators for visibility conditions. `needsValue` decides
// whether a value input is shown; `failed`/`answered` read the referenced item's
// status and need none. Mirrors the ops in Fleetms.Inspections.Condition.
export const CONDITION_OPS = [
  {value: "eq", label: "is", needsValue: true},
  {value: "neq", label: "is not", needsValue: true},
  {value: "failed", label: "failed", needsValue: false},
  {value: "answered", label: "is answered", needsValue: false},
  {value: "gt", label: "greater than", needsValue: true},
  {value: "lt", label: "less than", needsValue: true}
]

export function newRule() {
  return {item: "", op: "failed", value: ""}
}

export function newCondition() {
  return {op: "all", rules: [newRule()]}
}

export function uid() {
  return crypto.randomUUID().slice(0, 8)
}

// Moves element at index `i` by `dir` (-1 up / +1 down), in place. No-op at the
// ends. Splicing a Svelte $state array mutates it reactively.
export function moveInPlace(arr, i, dir) {
  const j = i + dir
  if (j < 0 || j >= arr.length) return
  const [el] = arr.splice(i, 1)
  arr.splice(j, 0, el)
}

// Moves the element at `from` to index `to`, in place (used by drag-and-drop).
// No-op when the indices are equal or out of range.
export function moveItem(arr, from, to) {
  if (from === to || from < 0 || to < 0 || from >= arr.length || to >= arr.length) return
  const [el] = arr.splice(from, 1)
  arr.splice(to, 0, el)
}
