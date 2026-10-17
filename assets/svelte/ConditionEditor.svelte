<script>
  // Authors a node's `visible_when` condition: "show this [item|section] when
  // [all|any] of these rules are true", each rule referencing an item. Mutates
  // `node.visible_when` in place (null when there is no condition). `candidates`
  // is the list of items a rule may reference. Matches the predicate shape
  // evaluated by Fleetms.Inspections.Condition.
  import {CONDITION_OPS, newRule, newCondition} from "./lib/itemTypes.js"

  let {node, candidates, label = "item"} = $props()

  const opMeta = Object.fromEntries(CONDITION_OPS.map((o) => [o.value, o]))

  const input =
    "rounded border border-gray-300 bg-white px-3 py-2.5 text-sm dark:border-gray-600 dark:bg-gray-800 dark:text-white"

  function enable() {
    node.visible_when = newCondition()
  }

  function disable() {
    node.visible_when = null
  }

  function addRule() {
    node.visible_when.rules.push(newRule())
  }

  function removeRule(i) {
    node.visible_when.rules.splice(i, 1)
    if (node.visible_when.rules.length === 0) node.visible_when = null
  }
</script>

<div class="border-t border-gray-100 pt-3 dark:border-gray-700">
  {#if !node.visible_when}
    <button
      type="button"
      class="inline-flex items-center gap-1 rounded-base border border-brand bg-transparent px-3 py-1.5 text-xs font-medium text-brand hover:bg-brand-softer"
      onclick={enable}
    >
      + Add visibility rule
    </button>
  {:else}
    <div class="space-y-2">
      <div class="flex flex-wrap items-center gap-2 text-sm text-gray-600 dark:text-gray-300">
        <span>Show this {label} when</span>
        <select class={input} bind:value={node.visible_when.op}>
          <option value="all">all</option>
          <option value="any">any</option>
        </select>
        <span>of these are true:</span>
      </div>

      {#each node.visible_when.rules as rule, i (i)}
        <div class="flex flex-wrap items-center gap-2">
          <select class={input} bind:value={rule.item}>
            <option value="">Select item…</option>
            {#each candidates as c}
              <option value={c.id}>{c.label || "(untitled)"}</option>
            {/each}
          </select>
          <select class={input} bind:value={rule.op}>
            {#each CONDITION_OPS as o}
              <option value={o.value}>{o.label}</option>
            {/each}
          </select>
          {#if opMeta[rule.op]?.needsValue}
            <input class={`${input} w-32`} placeholder="value" bind:value={rule.value} />
          {/if}
          <button type="button" class="px-1 text-red-500 hover:text-red-700" onclick={() => removeRule(i)}>✕</button>
        </div>
      {/each}

      <div class="flex items-center gap-3">
        <button
          type="button"
          class="inline-flex items-center gap-1 rounded-base border border-brand bg-transparent px-3 py-1.5 text-xs font-medium text-brand hover:bg-brand-softer"
          onclick={addRule}
        >
          + Add rule
        </button>
        <button type="button" class="text-xs text-gray-500 hover:underline" onclick={disable}>
          Remove visibility rule
        </button>
      </div>
    </div>
  {/if}
</div>
