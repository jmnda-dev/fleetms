defmodule Fleetms.Inspections.Inspection.Changes.RunWorkflows do
  @moduledoc """
  Stamps `workflows_ran_at` and runs the form's workflows against this inspection.

  Invoked by the `run_workflows` Oban trigger (system, actor-less). The timestamp
  is set as part of the update so, once committed, the trigger's `is_nil(...)`
  filter no longer matches and the inspection is never processed again.

  The engine (`Fleetms.Inspections.Workflows`) runs in `after_transaction`, i.e.
  *after* the stamp commits and outside this update's transaction — so the issues
  it opens are each their own clean transaction (their own after-transaction
  notifications aren't nested inside ours). It runs only on success and is wrapped
  best-effort, so a failure can neither roll back the stamp nor crash the job into
  a retry that would double-run the actions.
  """
  use Ash.Resource.Change

  require Logger

  alias Fleetms.Inspections.Workflows

  @impl true
  def change(changeset, _opts, context) do
    changeset
    |> Ash.Changeset.force_change_attribute(
      :workflows_ran_at,
      DateTime.truncate(DateTime.utc_now(), :second)
    )
    |> Ash.Changeset.after_transaction(fn
      _changeset, {:ok, inspection} = result ->
        run_workflows(inspection, context)
        result

      _changeset, result ->
        result
    end)
  end

  defp run_workflows(inspection, context) do
    opts = Ash.Context.to_opts(context, authorize?: false)
    loaded = Ash.load!(inspection, Workflows.load_requirements(), opts)
    Workflows.run(loaded, opts)
  rescue
    error ->
      Logger.error(
        "Inspection workflows failed for inspection #{inspection.id}: #{Exception.message(error)}"
      )

      :ok
  end
end
