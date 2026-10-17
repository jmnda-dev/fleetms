defmodule Fleetms.VehicleManagement.RenewalDigest do
  @moduledoc """
  Builds and sends the daily "renewals due" email digest for one organization.

  Called per tenant by the `VehicleRenewal.send_due_digest` scheduled action (which
  AshOban runs once per organization). It gathers the org's Due Soon / Overdue
  renewals and emails a summary to the organization's owner(s). It is purely a
  notifier — the renewal `status` is already correct on its own; this just tells
  someone about it. Runs unauthorized (a system job, no actor).
  """
  require Ash.Query

  import Swoosh.Email

  alias Fleetms.{Accounts, Emails, Mailer}
  alias Fleetms.VehicleManagement.VehicleRenewal

  @due_statuses ["Due Soon", "Overdue"]

  @doc """
  Sends the digest for the given tenant (an `org_<id>` schema string). Returns
  `{:ok, count}` where `count` is how many recipients were emailed (0 if nothing is
  due or the org has no reachable owner).
  """
  @spec deliver_for_tenant(String.t()) :: {:ok, non_neg_integer()}
  def deliver_for_tenant(tenant) do
    case due_renewals(tenant) do
      [] ->
        {:ok, 0}

      renewals ->
        org_id = org_id_from_tenant(tenant)
        recipients = owner_emails(org_id)

        if recipients == [] do
          {:ok, 0}
        else
          org = Accounts.get_organization!(org_id, authorize?: false)
          deliver(recipients, org, renewals)
          {:ok, length(recipients)}
        end
    end
  end

  defp due_renewals(tenant) do
    VehicleRenewal
    |> Ash.Query.filter(status in ^@due_statuses)
    |> Ash.Query.load([:status, :vehicle, :renewal_type])
    |> Ash.Query.sort(due_date: :asc)
    |> Ash.read!(tenant: tenant, authorize?: false)
  end

  defp owner_emails(org_id) do
    Accounts.list_user_organizations!(
      query: [filter: [organization_id: org_id, owner?: true]],
      load: [user: [:email]],
      authorize?: false
    )
    |> Enum.map(&to_string(&1.user.email))
    |> Enum.reject(&(&1 == ""))
  end

  defp org_id_from_tenant("org_" <> id), do: id
  defp org_id_from_tenant(tenant), do: tenant

  defp deliver(recipients, org, renewals) do
    new()
    |> from({"FleetMS", "noreply@fleetms.app"})
    |> to(recipients)
    |> subject("#{length(renewals)} vehicle renewal(s) due — #{org.name}")
    |> html_body(body(org, renewals))
    |> Mailer.deliver!()
  end

  defp body(org, renewals) do
    rows =
      Enum.map_join(renewals, "", fn renewal ->
        """
        <tr>
          <td>#{Emails.escape(renewal.vehicle.name)}</td>
          <td>#{Emails.escape(renewal.renewal_type.name)}</td>
          <td>#{Emails.escape(renewal.due_date)}</td>
          <td>#{Emails.escape(renewal.status)}</td>
        </tr>
        """
      end)

    """
    <h2>Renewals due for #{Emails.escape(org.name)}</h2>
    <p>The following vehicle renewals are due soon or overdue:</p>
    <table>
      <thead>
        <tr><th>Vehicle</th><th>Type</th><th>Due</th><th>Status</th></tr>
      </thead>
      <tbody>#{rows}</tbody>
    </table>
    """
  end
end
