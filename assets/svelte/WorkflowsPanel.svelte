<script>
  // Authors the form's workflows: "when a trigger fires on a submitted inspection,
  // then run these actions". Mutates the workflows array (and each workflow) in
  // place. The flat shape here matches the map_with_tag JSON the server expects for
  // Fleetms.Inspections.Schema.Workflow (trigger + actions unions).
  import {
    TRIGGER_TYPES,
    TRIGGER_META,
    ACTION_TYPES,
    ACTION_META,
    PRIORITIES,
    ASSIGN_TARGETS,
    NOTIFY_TARGETS,
    NOTIFY_CHANNELS,
    TEMPLATE_HINT,
    newTrigger,
    defaultActionConfig,
    newWorkflow
  } from "./lib/workflowTypes.js"

  let {workflows, allItems, users, roles = []} = $props()

  const input =
    "rounded border border-gray-300 bg-white px-3 py-2.5 text-sm dark:border-gray-600 dark:bg-gray-800 dark:text-white"
  const label = "block text-xs font-medium text-gray-500 dark:text-gray-400 mb-1"
  const hint = "mt-1 text-[11px] text-gray-400 dark:text-gray-500"

  function addWorkflow() {
    workflows.push(newWorkflow())
  }

  function removeWorkflow(i) {
    workflows.splice(i, 1)
  }

  function changeTrigger(workflow, type) {
    workflow.trigger = newTrigger(type)
  }

  function addAction(workflow, type) {
    workflow.actions.push(defaultActionConfig(type))
  }

  function removeAction(workflow, ai) {
    workflow.actions.splice(ai, 1)
  }
</script>

<div class="space-y-4">
  <p class="text-sm text-gray-500 dark:text-gray-400">
    Automations that run when an inspection built from this form is submitted.
  </p>

  {#each workflows as workflow, i (workflow.id)}
    <div class="rounded-lg border border-gray-200 bg-gray-50 p-3 dark:border-gray-700 dark:bg-gray-900">
      <div class="mb-3 flex items-center gap-2">
        <input
          class={`${input} flex-1`}
          placeholder="Workflow name (optional)"
          bind:value={workflow.name}
        />
        <label class="flex items-center gap-1 text-xs text-gray-600 dark:text-gray-300">
          <input type="checkbox" bind:checked={workflow.enabled} /> Enabled
        </label>
        <button
          type="button"
          class="px-1 text-red-500 hover:text-red-700"
          title="Remove workflow"
          onclick={() => removeWorkflow(i)}>✕</button>
      </div>

      <!-- Trigger -->
      <div class="flex flex-wrap items-center gap-2">
        <span class="text-sm font-medium text-gray-600 dark:text-gray-300">When</span>
        <select
          class={input}
          value={workflow.trigger.type}
          onchange={(e) => changeTrigger(workflow, e.currentTarget.value)}
        >
          {#each TRIGGER_TYPES as t}
            <option value={t.type}>{t.label}</option>
          {/each}
        </select>

        {#if TRIGGER_META[workflow.trigger.type]?.needsItem}
          <select class={input} bind:value={workflow.trigger.item_id}>
            <option value="">Select item…</option>
            {#each allItems as item}
              <option value={item.id}>{item.label || "(untitled)"}</option>
            {/each}
          </select>
        {/if}
      </div>

      <!-- Actions -->
      <div class="mt-3 space-y-2 border-t border-gray-200 pt-3 dark:border-gray-700">
        <span class="text-sm font-medium text-gray-600 dark:text-gray-300">Then</span>

        {#each workflow.actions as action, ai (ai)}
          <div class="rounded border border-gray-200 bg-white p-2 dark:border-gray-700 dark:bg-gray-800">
            <div class="mb-2 flex items-center justify-between">
              <span class="text-xs font-semibold text-gray-700 dark:text-gray-200">
                {ACTION_META[action.type]?.label ?? action.type}
              </span>
              <button
                type="button"
                class="px-1 text-red-500 hover:text-red-700"
                title="Remove action"
                onclick={() => removeAction(workflow, ai)}>✕</button>
            </div>

            {#if action.type === "open_issue"}
              <div class="grid gap-2 sm:grid-cols-2">
                <div class="sm:col-span-2">
                  <label class={label}>Issue title</label>
                  <input class={`${input} w-full`} bind:value={action.title_template} />
                  <p class={hint}>Placeholders: {TEMPLATE_HINT}</p>
                </div>
                <div>
                  <label class={label}>Priority</label>
                  <select class={`${input} w-full`} bind:value={action.priority}>
                    {#each PRIORITIES as p}
                      <option value={p}>{p}</option>
                    {/each}
                  </select>
                </div>
                <div>
                  <label class={label}>Assign to</label>
                  <select class={`${input} w-full`} bind:value={action.assign_to}>
                    {#each ASSIGN_TARGETS as t}
                      <option value={t.value}>{t.label}</option>
                    {/each}
                  </select>
                </div>
                {#if action.assign_to === "user"}
                  <div class="sm:col-span-2">
                    <label class={label}>Member</label>
                    <select class={`${input} w-full`} bind:value={action.assignee_user_id}>
                      <option value={null}>Select member…</option>
                      {#each users as u}
                        <option value={u.id}>{u.name}</option>
                      {/each}
                    </select>
                  </div>
                {/if}
              </div>
            {:else if action.type === "notify"}
              <div class="grid gap-2 sm:grid-cols-2">
                <div>
                  <label class={label}>Notify</label>
                  <select class={`${input} w-full`} bind:value={action.to}>
                    {#each NOTIFY_TARGETS as t}
                      <option value={t.value}>{t.label}</option>
                    {/each}
                  </select>
                </div>
                {#if action.to === "user"}
                  <div>
                    <label class={label}>Member</label>
                    <select class={`${input} w-full`} bind:value={action.recipient_user_id}>
                      <option value={null}>Select member…</option>
                      {#each users as u}
                        <option value={u.id}>{u.name}</option>
                      {/each}
                    </select>
                  </div>
                {:else if action.to === "role"}
                  <div>
                    <label class={label}>Role</label>
                    <select class={`${input} w-full`} bind:value={action.role_id}>
                      <option value={null}>Select role…</option>
                      {#each roles as r}
                        <option value={r.id}>{r.name}</option>
                      {/each}
                    </select>
                  </div>
                {/if}
                <div>
                  <label class={label}>Deliver via</label>
                  <select class={`${input} w-full`} bind:value={action.channel}>
                    {#each NOTIFY_CHANNELS as c}
                      <option value={c.value}>{c.label}</option>
                    {/each}
                  </select>
                </div>
                <div class="sm:col-span-2">
                  <label class={label}>Title</label>
                  <input class={`${input} w-full`} bind:value={action.title_template} />
                  <p class={hint}>Placeholders: {TEMPLATE_HINT}</p>
                </div>
                <div class="sm:col-span-2">
                  <label class={label}>Message (optional)</label>
                  <input class={`${input} w-full`} bind:value={action.body_template} />
                </div>
              </div>
            {/if}
          </div>
        {/each}

        <div class="flex items-center gap-3">
          {#each ACTION_TYPES as a}
            <button
              type="button"
              class="inline-flex items-center gap-1 rounded-base border border-brand bg-transparent px-3 py-1.5 text-xs font-medium text-brand hover:bg-brand-softer"
              onclick={() => addAction(workflow, a.type)}
            >
              + {a.label}
            </button>
          {/each}
        </div>
      </div>
    </div>
  {/each}

  <button
    type="button"
    onclick={addWorkflow}
    class="w-full rounded-lg border border-dashed border-gray-300 px-4 py-2 text-sm font-medium text-gray-600 hover:bg-gray-50 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-800"
  >
    + Add workflow
  </button>
</div>
