defmodule Fleetms.Inspections.Inspection.Changes.GradeAndFinalize do
  @moduledoc """
  Grades a submitted inspection against the version it was filled on and finalizes
  it: stores the graded answers and overall result, denormalizes the form id, and
  creates a failure row for every failed item — all in the submit transaction.

  Runs as a `before_action` so the managed `failures` are created together with
  the inspection. The version's frozen schema (not the live form) is the source of
  truth, and the vehicle's current odometer is passed through so meter items can
  enforce non-decrease.

  Finalizing also kicks off the form's **workflows**: if the version has any, an
  Oban job is enqueued (after commit) to run them against the new inspection; if it
  has none, `workflows_ran_at` is stamped now so no background work is scheduled and
  the trigger's filter never matches.
  """
  use Ash.Resource.Change

  alias Fleetms.Inspections.{Grade, Inspection, InspectionFormVersion}
  alias Fleetms.VehicleManagement.Vehicle

  @impl true
  def change(changeset, _opts, context) do
    changeset
    |> Ash.Changeset.before_action(fn changeset ->
      opts = Ash.Context.to_opts(context, authorize?: false)

      version_id = Ash.Changeset.get_attribute(changeset, :inspection_form_version_id)
      vehicle_id = Ash.Changeset.get_attribute(changeset, :vehicle_id)
      raw_answers = Ash.Changeset.get_argument(changeset, :answers) || []

      version = Ash.get!(InspectionFormVersion, version_id, opts)
      mileage = vehicle_mileage(vehicle_id, opts)

      %{result: result, answers: answers, failures: failures} =
        Grade.grade(version.schema, raw_answers, vehicle_mileage: mileage)

      has_workflows? = (version.schema.workflows || []) != []

      changeset
      |> Ash.Changeset.force_change_attribute(:inspection_form_id, version.inspection_form_id)
      |> Ash.Changeset.force_change_attribute(:answers, answers)
      |> Ash.Changeset.force_change_attribute(:result, result)
      |> Ash.Changeset.manage_relationship(:failures, failures, type: :create)
      |> Ash.Changeset.set_context(%{run_inspection_workflows?: has_workflows?})
      |> stamp_no_workflows(has_workflows?)
    end)
    |> Ash.Changeset.after_transaction(fn
      changeset, {:ok, inspection} = result ->
        if changeset.context[:run_inspection_workflows?] do
          # The job stores its tenant, so pass the primitive "org_<id>" string
          # rather than the Organization struct carried on the scope.
          tenant = Ash.ToTenant.to_tenant(context.tenant, Inspection)
          AshOban.run_trigger(inspection, :run_workflows, actor: nil, tenant: tenant)
        end

        result

      _changeset, result ->
        result
    end)
  end

  # No workflows to run — mark done immediately so the trigger never picks it up.
  defp stamp_no_workflows(changeset, true), do: changeset

  defp stamp_no_workflows(changeset, false) do
    Ash.Changeset.force_change_attribute(
      changeset,
      :workflows_ran_at,
      DateTime.truncate(DateTime.utc_now(), :second)
    )
  end

  defp vehicle_mileage(nil, _opts), do: nil

  defp vehicle_mileage(vehicle_id, opts) do
    case Ash.get(Vehicle, vehicle_id, opts) do
      {:ok, vehicle} -> vehicle.mileage
      _ -> nil
    end
  end
end
