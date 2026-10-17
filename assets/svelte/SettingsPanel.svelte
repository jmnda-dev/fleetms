<script>
  // Form-wide settings (see Fleetms.Inspections.Schema.Settings). Mutates the
  // settings object in place.
  let {settings} = $props()

  const input =
    "w-full rounded border border-gray-300 bg-white px-3 py-2.5 text-sm dark:border-gray-600 dark:bg-gray-800 dark:text-white"
  const label = "block text-xs font-medium text-gray-500 dark:text-gray-400 mb-1"
</script>

<div class="grid gap-3 sm:grid-cols-2">
  <div>
    <label class={label}>Pass policy</label>
    <select class={input} bind:value={settings.pass_policy}>
      <option value="all_pass">All items must pass</option>
      <option value="threshold">Allow up to N failures</option>
    </select>
  </div>

  {#if settings.pass_policy === "threshold"}
    <div>
      <label class={label}>Max failures still passing</label>
      <input type="number" min="0" class={input} bind:value={settings.fail_threshold} />
    </div>
  {:else}
    <div></div>
  {/if}

  <div>
    <label class={label}>Default meter unit</label>
    <input class={input} placeholder="km" bind:value={settings.meter_unit} />
  </div>
  <div></div>

  <label class="flex items-center gap-2 text-sm text-gray-700 dark:text-gray-200">
    <input type="checkbox" bind:checked={settings.require_signature} /> Require a signature to submit
  </label>
  <label class="flex items-center gap-2 text-sm text-gray-700 dark:text-gray-200">
    <input type="checkbox" bind:checked={settings.allow_partial_save} /> Allow saving a partial inspection
  </label>
</div>
