<script>
  // Renders the type-specific configuration fields for one item, switching on
  // `config.type`. Mutates the config object in place (it is part of the builder's
  // reactive document). Field sets mirror the Ash `*Config` embedded resources.
  import {EVENT_RULES} from "./lib/itemTypes.js"
  import OptionsEditor from "./OptionsEditor.svelte"

  let {config} = $props()

  const input =
    "w-full rounded border border-gray-300 bg-white px-3 py-2.5 text-sm dark:border-gray-600 dark:bg-gray-800 dark:text-white"
  const label = "block text-xs font-medium text-gray-500 dark:text-gray-400 mb-1"
</script>

{#snippet eventRule(text, key)}
  <div>
    <label class={label}>{text}</label>
    <select class={input} bind:value={config[key]}>
      {#each EVENT_RULES as rule}
        <option value={rule.value}>{rule.label}</option>
      {/each}
    </select>
  </div>
{/snippet}

<div class="grid gap-3 sm:grid-cols-2">
  {#if config.type === "pass_fail"}
    <div>
      <label class={label}>Pass label</label>
      <input class={input} bind:value={config.pass_label} />
    </div>
    <div>
      <label class={label}>Fail label</label>
      <input class={input} bind:value={config.fail_label} />
    </div>
    <label class="flex items-center gap-2 text-sm text-gray-700 dark:text-gray-200">
      <input type="checkbox" bind:checked={config.allow_na} /> Allow N/A
    </label>
    <div></div>
    {@render eventRule("Require comment", "comment_on")}
    {@render eventRule("Require photo", "photo_on")}
  {:else if config.type === "single_select"}
    <div>
      <label class={label}>Display as</label>
      <select class={input} bind:value={config.display}>
        <option value="dropdown">Dropdown</option>
        <option value="radio">Radio buttons</option>
      </select>
    </div>
    <div></div>
    <div class="sm:col-span-2"><OptionsEditor options={config.options} /></div>
    {@render eventRule("Require comment", "comment_on")}
    {@render eventRule("Require photo", "photo_on")}
  {:else if config.type === "multi_select"}
    <div>
      <label class={label}>Min selected</label>
      <input type="number" min="0" class={input} bind:value={config.min_selected} />
    </div>
    <div>
      <label class={label}>Max selected</label>
      <input type="number" min="1" class={input} bind:value={config.max_selected} />
    </div>
    <label class="flex items-center gap-2 text-sm text-gray-700 dark:text-gray-200 sm:col-span-2">
      <input type="checkbox" bind:checked={config.fail_if_any_fail_option} /> Fail if any failing option is chosen
    </label>
    <div class="sm:col-span-2"><OptionsEditor options={config.options} /></div>
    {@render eventRule("Require comment", "comment_on")}
  {:else if config.type === "number"}
    <div>
      <label class={label}>Unit</label>
      <input class={input} placeholder="e.g. psi" bind:value={config.unit} />
    </div>
    <div>
      <label class={label}>Decimals</label>
      <input type="number" min="0" max="6" class={input} bind:value={config.decimals} />
    </div>
    <div>
      <label class={label}>Passing range — min</label>
      <input type="number" class={input} bind:value={config.pass_min} />
    </div>
    <div>
      <label class={label}>Passing range — max</label>
      <input type="number" class={input} bind:value={config.pass_max} />
    </div>
    {@render eventRule("Require comment", "comment_on")}
    {@render eventRule("Require photo", "photo_on")}
  {:else if config.type === "meter"}
    <div>
      <label class={label}>Unit</label>
      <input class={input} placeholder="e.g. km" bind:value={config.unit} />
    </div>
    <div></div>
    <label class="flex items-center gap-2 text-sm text-gray-700 dark:text-gray-200">
      <input type="checkbox" bind:checked={config.write_to_vehicle} /> Update vehicle odometer
    </label>
    <label class="flex items-center gap-2 text-sm text-gray-700 dark:text-gray-200">
      <input type="checkbox" bind:checked={config.must_increase} /> Must not decrease
    </label>
    {@render eventRule("Require comment", "comment_on")}
  {:else if config.type === "date"}
    <div>
      <label class={label}>Mode</label>
      <select class={input} bind:value={config.mode}>
        <option value="date">Date</option>
        <option value="datetime">Date &amp; time</option>
      </select>
    </div>
    <div></div>
    <label class="flex items-center gap-2 text-sm text-gray-700 dark:text-gray-200">
      <input type="checkbox" bind:checked={config.fail_if_past} /> Fail if in the past
    </label>
    <label class="flex items-center gap-2 text-sm text-gray-700 dark:text-gray-200">
      <input type="checkbox" bind:checked={config.fail_if_future} /> Fail if in the future
    </label>
  {:else if config.type === "text"}
    <label class="flex items-center gap-2 text-sm text-gray-700 dark:text-gray-200">
      <input type="checkbox" bind:checked={config.multiline} /> Multi-line
    </label>
    <div>
      <label class={label}>Max length</label>
      <input type="number" min="1" class={input} bind:value={config.max_length} />
    </div>
  {:else if config.type === "photo"}
    <div>
      <label class={label}>Min photos</label>
      <input type="number" min="0" class={input} bind:value={config.min_photos} />
    </div>
    <div>
      <label class={label}>Max photos</label>
      <input type="number" min="1" class={input} bind:value={config.max_photos} />
    </div>
  {:else if config.type === "signature"}
    <div>
      <label class={label}>Prompt</label>
      <input class={input} placeholder="e.g. Inspector signature" bind:value={config.prompt} />
    </div>
    <div>
      <label class={label}>Signed by</label>
      <select class={input} bind:value={config.who}>
        <option value="inspector">Inspector</option>
        <option value="driver">Driver</option>
        <option value="reviewer">Reviewer</option>
      </select>
    </div>
  {:else if config.type === "instruction"}
    <div class="sm:col-span-2">
      <label class={label}>Instruction text</label>
      <textarea rows="3" class={input} bind:value={config.body}></textarea>
    </div>
  {/if}
</div>
