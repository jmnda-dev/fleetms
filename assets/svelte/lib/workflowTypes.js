// The catalog for the workflow builder — triggers and actions — mirroring the Ash
// unions in `Fleetms.Inspections.Schema.Workflow` (triggers) and its `*Action`
// resources. Defaults here match those resources' attribute defaults so a freshly
// added workflow/action is already valid on the server. Keep in sync with them.

import {uid} from "./itemTypes.js"

export const TRIGGER_TYPES = [
  {type: "inspection_submitted", label: "Inspection is submitted", needsItem: false},
  {type: "inspection_failed", label: "Inspection fails overall", needsItem: false},
  {type: "any_item_failed", label: "Any item fails", needsItem: false},
  {type: "item_failed", label: "A specific item fails", needsItem: true}
]

export const TRIGGER_META = Object.fromEntries(TRIGGER_TYPES.map((t) => [t.type, t]))

export const ACTION_TYPES = [
  {type: "open_issue", label: "Open an issue", icon: "fa-triangle-exclamation"},
  {type: "notify", label: "Send a notification", icon: "fa-bell"}
]

export const ACTION_META = Object.fromEntries(ACTION_TYPES.map((a) => [a.type, a]))

// Matches Fleetms.VehicleIssues.IssuePriority.
export const PRIORITIES = ["None", "Low", "Medium", "High"]

export const ASSIGN_TARGETS = [
  {value: "unassigned", label: "Leave unassigned"},
  {value: "submitter", label: "Whoever submitted it"},
  {value: "user", label: "A specific member"}
]

export const NOTIFY_TARGETS = [
  {value: "submitter", label: "Whoever submitted it"},
  {value: "user", label: "A specific member"},
  {value: "role", label: "Everyone with a role"},
  {value: "owners", label: "Organization owners"}
]

// How a notification reaches recipients. Matches NotifyAction's `channel`.
export const NOTIFY_CHANNELS = [
  {value: "in_app", label: "In-app (bell)"},
  {value: "email", label: "Email"},
  {value: "both", label: "In-app + email"}
]

// Placeholders the engine (Fleetms.Inspections.Workflows.render/2) understands,
// shown as a hint under template inputs.
export const TEMPLATE_HINT = "{vehicle} {form} {result} {failed_count} {submitter} {item}"

export function newTrigger(type) {
  return type === "item_failed" ? {type, item_id: ""} : {type}
}

export function defaultActionConfig(type) {
  switch (type) {
    case "open_issue":
      return {
        type,
        title_template: "Inspection failure on {vehicle}",
        priority: "Medium",
        assign_to: "unassigned",
        assignee_user_id: null
      }
    case "notify":
      return {
        type,
        to: "user",
        recipient_user_id: null,
        role_id: null,
        channel: "in_app",
        title_template: "Inspection needs attention on {vehicle}",
        body_template: ""
      }
    default:
      return {type}
  }
}

export function newWorkflow() {
  return {
    id: uid(),
    name: "",
    enabled: true,
    trigger: {type: "inspection_failed"},
    actions: [defaultActionConfig("open_issue")]
  }
}
