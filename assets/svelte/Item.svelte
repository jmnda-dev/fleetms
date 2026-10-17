<script>
  // One item within a section: a header (drag handle, type badge, label preview,
  // reorder, expand/collapse, remove) and, when expanded, the common fields plus
  // the type-specific config panel. Mutates `item` in place. Drag reorders items
  // within the section; the ↑/↓ buttons are the keyboard-accessible equivalent.
  import {TYPE_META} from "./lib/itemTypes.js"
  import ConfigPanel from "./ConfigPanel.svelte"
  import ConditionEditor from "./ConditionEditor.svelte"

  let {
    item,
    allItems,
    remove,
    moveUp,
    moveDown,
    first,
    last,
    dragging = false,
    onDragStart,
    onDragOver,
    onDragEnd
  } = $props()

  let expanded = $state(true)
  let grabbed = $state(false)
  let meta = $derived(TYPE_META[item.config.type] ?? {label: item.config.type})

  function handleDragStart(e) {
    onDragStart?.()
    e.dataTransfer.effectAllowed = "move"
    e.dataTransfer.setData("text/plain", "")
    e.dataTransfer.setDragImage(e.currentTarget, 16, 16)
  }

  function handleDragEnd() {
    grabbed = false
    onDragEnd?.()
  }

  const input =
    "w-full rounded border border-gray-300 bg-white px-3 py-2.5 text-sm dark:border-gray-600 dark:bg-gray-800 dark:text-white"
  const label = "block text-xs font-medium text-gray-500 dark:text-gray-400 mb-1"
  const iconBtn =
    "px-2 py-1 text-gray-400 hover:text-gray-700 disabled:opacity-30 dark:hover:text-gray-200"
</script>

<!-- Drag is a pointer-only enhancement; keyboard users reorder with the ↑/↓ buttons. -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  role="listitem"
  class={`rounded-lg border bg-white dark:bg-gray-800 ${dragging ? "border-brand opacity-60 ring-2 ring-brand" : "border-gray-200 dark:border-gray-700"}`}
  draggable={grabbed}
  ondragstart={handleDragStart}
  ondragover={(e) => {
    e.preventDefault()
    onDragOver?.()
  }}
  ondrop={(e) => e.preventDefault()}
  ondragend={handleDragEnd}
>
  <div class="flex items-center gap-2 p-3">
    <span
      class="cursor-grab select-none text-lg leading-none text-gray-300 hover:text-gray-500 dark:text-gray-500 dark:hover:text-gray-300"
      aria-hidden="true"
      title="Drag to reorder item"
      onpointerdown={() => (grabbed = true)}
      onpointerup={() => (grabbed = false)}
    >
      ⠿
    </span>
    <span class="whitespace-nowrap rounded bg-brand-softer px-2 py-0.5 text-xs font-medium text-fg-brand">
      {meta.label}
    </span>
    <button
      type="button"
      class="flex-1 truncate text-left text-sm font-medium text-gray-800 dark:text-gray-100"
      aria-expanded={expanded}
      onclick={() => (expanded = !expanded)}
    >
      {item.label || "Untitled item"}
    </button>
    <button type="button" class={iconBtn} disabled={first} onclick={moveUp} aria-label="Move item up">↑</button>
    <button
      type="button"
      class={iconBtn}
      disabled={last}
      onclick={moveDown}
      aria-label="Move item down"
    >↓</button>
    <button
      type="button"
      class="px-2 py-1 text-xs text-gray-500 hover:text-gray-800 dark:text-gray-400 dark:hover:text-gray-200"
      aria-expanded={expanded}
      onclick={() => (expanded = !expanded)}
    >
      {expanded ? "Collapse" : "Edit"}
    </button>
    <button
      type="button"
      class="px-2 py-1 text-red-500 hover:text-red-700"
      onclick={remove}
      aria-label="Remove item"
    >✕</button>
  </div>

  {#if expanded}
    <div class="space-y-3 border-t border-gray-100 p-3 dark:border-gray-700">
      {#if item.config.type !== "instruction"}
        <div class="grid gap-3 sm:grid-cols-2">
          <div>
            <label class={label}>Label</label>
            <input class={input} placeholder="What is being checked?" bind:value={item.label} />
          </div>
          <div>
            <label class={label}>Help text</label>
            <input class={input} placeholder="Optional guidance" bind:value={item.help_text} />
          </div>
        </div>
        <label class="flex items-center gap-2 text-sm text-gray-700 dark:text-gray-200">
          <input type="checkbox" bind:checked={item.required} /> Required
        </label>
      {/if}

      <ConfigPanel config={item.config} />

      <ConditionEditor
        node={item}
        candidates={allItems.filter((c) => c.id !== item.id)}
        label="item"
      />
    </div>
  {/if}
</div>
