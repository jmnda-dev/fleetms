defmodule Fleetms.VehicleIssues.Issue.Changes.SetIssueNumber do
  @moduledoc """
  Assigns the per-organization `issue_number` from a Postgres sequence.

  Each tenant schema owns an `issues_number_seq` sequence (created by the custom
  statement in `Issue`'s `postgres` block, so every org schema gets its own). We
  draw the next value with `nextval`, which is concurrency-safe by design — it
  never hands the same number to two transactions and never rolls back — so issue
  numbers are gapless-per-org without locking or a counter row to contend on.

  Runs `before_action` so the value is set on the insert.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    schema = tenant_schema(context.tenant)

    # The sequence is schema-qualified and double-quoted (tenant schema names
    # contain hyphens). The schema is an internal `org_<uuid>` derived from the
    # tenant — never user input — so interpolating it into the regclass literal is
    # injection-safe, and avoids postgrex trying to encode a bind param as a
    # regclass OID.
    sql = ~s|SELECT nextval('"#{schema}".issues_number_seq')|

    Ash.Changeset.before_action(changeset, fn changeset ->
      %{rows: [[number]]} = Fleetms.Repo.query!(sql)
      Ash.Changeset.force_change_attribute(changeset, :issue_number, number)
    end)
  end

  defp tenant_schema(tenant) when is_binary(tenant), do: tenant
  defp tenant_schema(tenant), do: Ash.ToTenant.to_tenant(tenant, Fleetms.VehicleIssues.Issue)
end
