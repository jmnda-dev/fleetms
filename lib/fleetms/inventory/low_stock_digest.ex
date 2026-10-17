defmodule Fleetms.Inventory.LowStockDigest do
  @moduledoc """
  Builds and sends the daily "low stock" email digest for one organization.

  Called per tenant by the `Part.send_low_stock_digest` scheduled action (which
  AshOban runs once per organization). It gathers the org's tracked parts that are
  low or out of stock and emails a summary to the organization's owner(s). It is
  purely a notifier — a part's `stock_status` is derived live and always correct;
  this just tells someone about it. Runs unauthorized (a system job, no actor).

  Mirrors `Fleetms.Maintenance.ReminderDigest`.
  """
  require Ash.Query

  import Swoosh.Email

  alias Fleetms.Accounts
  alias Fleetms.Emails
  alias Fleetms.Inventory.Part
  alias Fleetms.Mailer

  @low_statuses ["Low", "Out of stock"]

  @doc """
  Sends the digest for the given tenant (an `org_<id>` schema string). Returns
  `{:ok, count}` where `count` is how many recipients were emailed (0 if nothing is
  low or the org has no reachable owner).
  """
  @spec deliver_for_tenant(String.t()) :: {:ok, non_neg_integer()}
  def deliver_for_tenant(tenant) do
    case low_parts(tenant) do
      [] ->
        {:ok, 0}

      parts ->
        org_id = org_id_from_tenant(tenant)
        recipients = owner_emails(org_id)

        if recipients == [] do
          {:ok, 0}
        else
          org = Accounts.get_organization!(org_id, authorize?: false)
          deliver(recipients, org, parts)
          {:ok, length(recipients)}
        end
    end
  end

  defp low_parts(tenant) do
    Part
    |> Ash.Query.filter(is_nil(archived_at) and track_inventory == true)
    |> Ash.Query.load([:stock_status, :total_stock])
    |> Ash.read!(tenant: tenant, authorize?: false)
    |> Enum.filter(&(&1.stock_status in @low_statuses))
    |> Enum.sort_by(&Decimal.to_float(&1.total_stock))
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

  defp deliver(recipients, org, parts) do
    new()
    |> from({"FleetMS", "noreply@fleetms.app"})
    |> to(recipients)
    |> subject("#{length(parts)} part(s) low on stock — #{org.name}")
    |> html_body(body(org, parts))
    |> Mailer.deliver!()
  end

  defp body(org, parts) do
    rows =
      Enum.map_join(parts, "", fn part ->
        """
        <tr>
          <td>#{Emails.escape(part.part_number)}</td>
          <td>#{Emails.escape(part.name)}</td>
          <td>#{Emails.escape(qty(part.total_stock))}</td>
          <td>#{Emails.escape(qty(part.quantity_threshold))}</td>
          <td>#{Emails.escape(part.stock_status)}</td>
        </tr>
        """
      end)

    """
    <h2>Low stock for #{Emails.escape(org.name)}</h2>
    <p>The following parts are at or below their reorder threshold:</p>
    <table>
      <thead>
        <tr><th>Part #</th><th>Name</th><th>On hand</th><th>Threshold</th><th>Status</th></tr>
      </thead>
      <tbody>#{rows}</tbody>
    </table>
    """
  end

  defp qty(nil), do: "—"
  defp qty(decimal), do: Decimal.to_string(decimal, :normal)
end
