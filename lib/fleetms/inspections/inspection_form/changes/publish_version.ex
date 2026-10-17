defmodule Fleetms.Inspections.InspectionForm.Changes.PublishVersion do
  @moduledoc """
  Freezes the form's current `draft_schema` into a new immutable
  `InspectionFormVersion` with the next per-form `version_number`, and marks the
  form active.

  The version number is computed from the highest existing version for this form
  (there is no global sequence — numbering is per form), then the snapshot is
  created in the same transaction via the `versions` relationship.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    schema = Ash.Changeset.get_attribute(changeset, :draft_schema)
    next_number = next_version_number(changeset.data, context)

    changeset
    |> Ash.Changeset.force_change_attribute(:status, :active)
    |> Ash.Changeset.manage_relationship(
      :versions,
      [%{version_number: next_number, schema: schema}],
      type: :create
    )
  end

  defp next_version_number(form, context) do
    opts = Ash.Context.to_opts(context, authorize?: false)
    form = Ash.load!(form, :latest_version_number, opts)
    (form.latest_version_number || 0) + 1
  end
end
