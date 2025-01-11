defmodule Fleetms.VehicleIssues.Issue.Changes.SetIssueNumber do
  use Ash.Resource.Change

  def change(changeset, _opts, %Ash.Resource.Change.Context{actor: actor, tenant: tenant}) do
    # TODO: Be sure to verify that the `lock` on the sequence does actually work and the record can not be updated during this transaction.
    sequence =
      Fleetms.Common.Sequence.get_issue_resource_sequence!(actor: actor, tenant: tenant)

    changeset
    |> Ash.Changeset.force_change_attribute(:issue_number, sequence.current_count)
    |> Ash.Changeset.after_action(fn _changeset, created_issue ->
      Fleetms.Common.Sequence.increment!(sequence, actor: actor, tenant: tenant)
      {:ok, created_issue}
    end)
  end
end
