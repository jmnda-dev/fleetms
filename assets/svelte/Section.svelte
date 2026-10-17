<script>
  // A section: title/description, its ordered items, and a menu to add an item of
  // any type. Items are reordered here (drag handle, or the ↑/↓ buttons for
  // keyboard users); the section itself is reordered/removed by the parent via the
  // passed callbacks. Drag reorders the list live as the pointer moves.
  import {ITEM_TYPES, GROUPS, newItem, moveInPlace, moveItem} from "./lib/itemTypes.js"
  import Item from "./Item.svelte"
  import ConditionEditor from "./ConditionEditor.svelte"

  let {
    section,
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

  let menuOpen = $state(false)
  // Set while the pointer is pressed on the drag handle, so the card is only
  // draggable then — leaving its text inputs normally editable otherwise.
  let grabbed = $state(false)

  // Item reorder within this section (mirrors the section reorder in the parent).
  let itemDragIndex = $state(null)

  function onItemDragStart(i) {
    itemDragIndex = i
  }

  function onItemDragOver(i) {
    if (itemDragIndex === null || itemDragIndex === i) return
    moveItem(section.items, itemDragIndex, i)
    itemDragIndex = i
  }

  function onItemDragEnd() {
    itemDragIndex = null
  }

  function handleDragStart(e) {
    onDragStart?.()
    e.dataTransfer.effectAllowed = "move"
    // Firefox only starts a drag when some data is set.
    e.dataTransfer.setData("text/plain", "")
    e.dataTransfer.setDragImage(e.currentTarget, 16, 16)
  }

  function handleDragEnd() {
    grabbed = false
    onDragEnd?.()
  }

  const input =
    "w-full rounded border border-gray-300 bg-white px-3 py-2.5 text-sm dark:border-gray-600 dark:bg-gray-700 dark:text-white"
  const iconBtn =
    "px-2 py-1 text-gray-400 hover:text-gray-700 disabled:opacity-30 dark:hover:text-gray-200"
</script>

<!-- Drag is a pointer-only enhancement; keyboard users reorder with the ↑/↓ buttons. -->
<!-- svelte-ignore a11y_no_static_element_interactions -->
<div
  role="listitem"
  class={`rounded-lg border bg-white p-4 shadow-sm dark:bg-gray-800 ${dragging ? "border-brand opacity-60 ring-2 ring-brand" : "border-gray-200 dark:border-gray-700"}`}
  draggable={grabbed}
  ondragstart={handleDragStart}
  ondragover={(e) => {
    e.preventDefault()
    onDragOver?.()
  }}
  ondrop={(e) => e.preventDefault()}
  ondragend={handleDragEnd}
>
  <div class="mb-3 flex items-start gap-2">
    <span
      class="mt-2 cursor-grab select-none px-1 text-lg leading-none text-gray-300 hover:text-gray-500 dark:text-gray-500 dark:hover:text-gray-300"
      aria-hidden="true"
      title="Drag to reorder section"
      onpointerdown={() => (grabbed = true)}
      onpointerup={() => (grabbed = false)}
    >
      ⠿
    </span>
    <div class="flex-1 space-y-2">
      <input class={`${input} font-medium`} placeholder="Section title" bind:value={section.title} />
      <input class={input} placeholder="Description (optional)" bind:value={section.description} />
    </div>
    <div class="flex items-center">
      <button
        type="button"
        class={iconBtn}
        disabled={first}
        onclick={moveUp}
        aria-label="Move section up"
      >↑</button>
      <button
        type="button"
        class={iconBtn}
        disabled={last}
        onclick={moveDown}
        aria-label="Move section down"
      >↓</button>
      <button
        type="button"
        class="ml-1 inline-flex items-center rounded-base border border-danger bg-transparent px-3 py-1.5 text-xs font-medium text-danger hover:bg-danger hover:text-white"
        onclick={remove}
        aria-label="Remove section"
      >
        Remove
      </button>
    </div>
  </div>

  <div role="list" aria-label="Section items" class="space-y-2">
    {#each section.items as item, i (item.id)}
      <Item
        {item}
        {allItems}
        first={i === 0}
        last={i === section.items.length - 1}
        dragging={itemDragIndex === i}
        onDragStart={() => onItemDragStart(i)}
        onDragOver={() => onItemDragOver(i)}
        onDragEnd={onItemDragEnd}
        moveUp={() => moveInPlace(section.items, i, -1)}
        moveDown={() => moveInPlace(section.items, i, 1)}
        remove={() => section.items.splice(i, 1)}
      />
    {/each}
    {#if section.items.length === 0}
      <p class="py-2 text-sm text-gray-400">No items yet — add one below.</p>
    {/if}
  </div>

  <div class="relative mt-3">
    <button
      type="button"
      class="rounded-lg border border-dashed border-gray-300 px-3 py-2 text-sm text-gray-600 hover:bg-gray-50 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-700"
      aria-expanded={menuOpen}
      onclick={() => (menuOpen = !menuOpen)}
    >
      + Add item
    </button>

    {#if menuOpen}
      <div
        class="absolute z-10 mt-1 w-80 rounded-lg border border-gray-200 bg-white p-2 shadow-lg dark:border-gray-700 dark:bg-gray-800"
      >
        {#each GROUPS as group}
          <p class="px-2 pb-1 pt-2 text-xs font-semibold uppercase text-gray-400">{group}</p>
          <div class="grid grid-cols-2 gap-1">
            {#each ITEM_TYPES.filter((t) => t.group === group) as type}
              <button
                type="button"
                class="rounded px-2 py-1.5 text-left text-sm text-gray-700 hover:bg-primary-50 dark:text-gray-200 dark:hover:bg-gray-700"
                onclick={() => {
                  section.items.push(newItem(type.type))
                  menuOpen = false
                }}
              >
                {type.label}
              </button>
            {/each}
          </div>
        {/each}
      </div>
    {/if}
  </div>

  <div class="mt-3">
    <ConditionEditor node={section} candidates={allItems} label="section" />
  </div>
</div>
