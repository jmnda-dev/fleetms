<script>
  // Editor for a single/multi-select item's options. Each option has a value, a
  // display label, and a `fail?` flag marking it as a failing answer.
  import {newOption, moveInPlace} from "./lib/itemTypes.js"

  let {options} = $props()

  const input =
    "rounded border border-gray-300 bg-white px-3 py-2.5 text-sm dark:border-gray-600 dark:bg-gray-800 dark:text-white"
</script>

<div class="space-y-2">
  <div class="flex items-center justify-between">
    <span class="text-xs font-medium uppercase text-gray-500 dark:text-gray-400">Options</span>
    <span class="text-xs text-gray-400">Tick "Fails" to make a choice a failing answer</span>
  </div>

  {#if options.length === 0}
    <p class="text-sm text-gray-400">No options yet.</p>
  {/if}

  {#each options as option, i (i)}
    <div class="flex items-center gap-2">
      <input class={`${input} w-28`} placeholder="value" bind:value={option.value} />
      <input class={`${input} flex-1`} placeholder="Label shown to the filler" bind:value={option.label} />
      <label class="flex items-center gap-1 text-xs text-gray-600 dark:text-gray-300">
        <input type="checkbox" bind:checked={option["fail?"]} /> Fails
      </label>
      <button type="button" class="px-1 text-gray-400 hover:text-gray-600" onclick={() => moveInPlace(options, i, -1)} title="Move up">↑</button>
      <button type="button" class="px-1 text-gray-400 hover:text-gray-600" onclick={() => moveInPlace(options, i, 1)} title="Move down">↓</button>
      <button type="button" class="px-1 text-red-500 hover:text-red-700" onclick={() => options.splice(i, 1)} title="Remove">✕</button>
    </div>
  {/each}

  <button
    type="button"
    class="rounded border border-dashed border-gray-300 px-2 py-1 text-xs text-gray-600 hover:bg-gray-50 dark:border-gray-600 dark:text-gray-300 dark:hover:bg-gray-700"
    onclick={() => options.push(newOption())}
  >
    + Add option
  </button>
</div>
