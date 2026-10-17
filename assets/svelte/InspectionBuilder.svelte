<script>
  // Root of the inspection form builder island. Owns a local, client-side copy of
  // the form document, edited entirely on the client; the whole document is pushed
  // back to the server (via the hook's onSave) only on an explicit save. Dirtiness
  // is derived by comparing the current document against the last-saved baseline,
  // so every edit anywhere in the tree is reflected without manual bookkeeping.
  import {untrack} from "svelte"
  import {newSection, moveInPlace, moveItem, uid} from "./lib/itemTypes.js"
  import Section from "./Section.svelte"
  import SettingsPanel from "./SettingsPanel.svelte"
  import WorkflowsPanel from "./WorkflowsPanel.svelte"

  let {schema, onSave, users = [], roles = []} = $props()

  let doc = $state(untrack(() => normalize(schema)))
  let baseline = $state(serialize(untrack(() => doc)))
  let showSettings = $state(false)
  let showWorkflows = $state(false)

  let serialized = $derived(serialize(doc))
  let dirty = $derived(serialized !== baseline)

  // Index of the section currently being dragged (null when not dragging). The
  // list reorders live as the pointer moves over other sections.
  let dragIndex = $state(null)

  function onSectionDragStart(i) {
    dragIndex = i
  }

  function onSectionDragOver(i) {
    if (dragIndex === null || dragIndex === i) return
    moveItem(doc.sections, dragIndex, i)
    dragIndex = i
  }

  function onSectionDragEnd() {
    dragIndex = null
  }
  let itemCount = $derived(doc.sections.reduce((n, s) => n + s.items.length, 0))

  // Flat list of every item, for the condition editor's item picker.
  let allItems = $derived(
    doc.sections.flatMap((s) => s.items).map((i) => ({id: i.id, label: i.label}))
  )

  function normalize(s) {
    return {
      schema_version: s?.schema_version ?? 1,
      settings: {
        pass_policy: s?.settings?.pass_policy ?? "all_pass",
        fail_threshold: s?.settings?.fail_threshold ?? null,
        require_signature: s?.settings?.require_signature ?? false,
        allow_partial_save: s?.settings?.allow_partial_save ?? true,
        meter_unit: s?.settings?.meter_unit ?? "km"
      },
      sections: (s?.sections ?? []).map((sec) => ({
        id: sec.id ?? uid(),
        title: sec.title ?? "",
        description: sec.description ?? "",
        visible_when: sec.visible_when ?? null,
        items: (sec.items ?? []).map((it) => ({
          id: it.id ?? uid(),
          label: it.label ?? "",
          help_text: it.help_text ?? "",
          required: it.required ?? false,
          visible_when: it.visible_when ?? null,
          config: it.config ?? {type: "pass_fail"}
        }))
      })),
      workflows: (s?.workflows ?? []).map((wf) => ({
        id: wf.id ?? uid(),
        name: wf.name ?? "",
        enabled: wf.enabled ?? true,
        trigger: wf.trigger ?? {type: "inspection_failed"},
        actions: wf.actions ?? []
      }))
    }
  }

  function serialize(d) {
    return JSON.stringify($state.snapshot(d))
  }

  function addSection() {
    doc.sections.push(newSection())
  }

  function save() {
    onSave?.(sanitize(JSON.parse(serialized)))
    baseline = serialized
  }

  // Drop fully-blank option rows before saving so a half-started "+ Add option"
  // doesn't fail validation for the whole document (a partially-filled option is
  // still sent, so genuine mistakes surface). The on-screen row stays until the
  // next reload.
  function sanitize(d) {
    for (const section of d.sections) {
      cleanCondition(section)
      for (const item of section.items) {
        const options = item.config?.options
        if (Array.isArray(options)) {
          item.config.options = options.filter(
            (o) => (o.value ?? "").trim() !== "" || (o.label ?? "").trim() !== ""
          )
        }
        cleanCondition(item)
      }
    }
    d.workflows = cleanWorkflows(d.workflows)
    return d
  }

  // Keep only workflows the server will accept and that actually do something:
  // an item trigger needs a chosen item, every action needs a non-blank title,
  // user targets that aren't "a specific member" shouldn't carry a stale id, and
  // a workflow with no valid actions is dropped. Half-built rows stay on screen
  // until the next reload (like blank options).
  function cleanWorkflows(workflows) {
    return workflows
      .map((wf) => {
        const actions = (wf.actions ?? [])
          .map(cleanAction)
          .filter((a) => (a.title_template ?? "").trim() !== "")
        return {...wf, actions}
      })
      .filter((wf) => wf.actions.length > 0)
      .filter((wf) => wf.trigger?.type !== "item_failed" || (wf.trigger.item_id ?? "") !== "")
  }

  function cleanAction(action) {
    if (action.type === "open_issue" && action.assign_to !== "user") {
      return {...action, assignee_user_id: null}
    }
    if (action.type === "notify") {
      return {
        ...action,
        recipient_user_id: action.to === "user" ? action.recipient_user_id : null,
        role_id: action.to === "role" ? action.role_id : null
      }
    }
    return action
  }

  // Drop rules with no referenced item, and clear a condition left with none, so
  // a half-built visibility rule can't hide the item or section outright on the
  // server. Works on any node carrying a `visible_when`.
  function cleanCondition(node) {
    const condition = node.visible_when
    if (!condition) return
    condition.rules = (condition.rules ?? []).filter((r) => (r.item ?? "") !== "")
    if (condition.rules.length === 0) node.visible_when = null
  }
</script>

<div class="space-y-4">
  <div class="flex flex-wrap items-center justify-between gap-2">
    <p class="text-sm text-gray-500 dark:text-gray-400">
      {doc.sections.length} section{doc.sections.length === 1 ? "" : "s"} · {itemCount} item{itemCount === 1 ? "" : "s"}
    </p>
    <div class="flex items-center gap-2">
      <button
        type="button"
        class="rounded-lg border border-gray-300 px-3 py-2 text-sm text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:text-gray-200 dark:hover:bg-gray-700"
        onclick={() => (showWorkflows = !showWorkflows)}
      >
        {showWorkflows ? "Hide workflows" : `Workflows${doc.workflows.length ? ` (${doc.workflows.length})` : ""}`}
      </button>
      <button
        type="button"
        class="rounded-lg border border-gray-300 px-3 py-2 text-sm text-gray-700 hover:bg-gray-50 dark:border-gray-600 dark:text-gray-200 dark:hover:bg-gray-700"
        onclick={() => (showSettings = !showSettings)}
      >
        {showSettings ? "Hide settings" : "Settings"}
      </button>
      {#if dirty}
        <span class="text-xs text-amber-600 dark:text-amber-400">Unsaved changes</span>
      {/if}
      <button
        type="button"
        onclick={save}
        disabled={!dirty}
        class="rounded-lg bg-brand px-4 py-2 text-sm font-medium text-white hover:bg-brand-strong disabled:opacity-50 dark:text-primary-900"
      >
        Save draft
      </button>
    </div>
  </div>

  {#if showSettings}
    <div class="rounded-lg border border-gray-200 bg-white p-4 shadow-sm dark:border-gray-700 dark:bg-gray-800">
      <SettingsPanel settings={doc.settings} />
    </div>
  {/if}

  {#if showWorkflows}
    <div class="rounded-lg border border-gray-200 bg-white p-4 shadow-sm dark:border-gray-700 dark:bg-gray-800">
      <WorkflowsPanel workflows={doc.workflows} {allItems} {users} {roles} />
    </div>
  {/if}

  <div role="list" aria-label="Form sections" class="space-y-4">
    {#each doc.sections as section, i (section.id)}
      <Section
        {section}
        {allItems}
        first={i === 0}
        last={i === doc.sections.length - 1}
        dragging={dragIndex === i}
        onDragStart={() => onSectionDragStart(i)}
        onDragOver={() => onSectionDragOver(i)}
        onDragEnd={onSectionDragEnd}
        moveUp={() => moveInPlace(doc.sections, i, -1)}
        moveDown={() => moveInPlace(doc.sections, i, 1)}
        remove={() => doc.sections.splice(i, 1)}
      />
    {/each}
  </div>

  <button
    type="button"
    onclick={addSection}
    class="w-full rounded-lg border border-dashed border-gray-300 px-4 py-3 text-sm font-medium text-gray-600 hover:bg-gray-50 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-800"
  >
    + Add section
  </button>
</div>
