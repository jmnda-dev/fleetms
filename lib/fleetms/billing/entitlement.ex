defmodule Fleetms.Billing.Entitlement do
  @moduledoc """
  Read-side helpers for an organization's billing standing — used to surface
  dunning notices in the UI.
  """
  alias Fleetms.Billing

  @doc """
  A dunning notice for an org, based on its latest subscription:

    * `:past_due` — a renewal payment is outstanding (still within grace).
    * `:expired`  — the subscription has lapsed.
    * `nil`       — nothing to flag (no subscription, or it's current).
  """
  @spec notice_for_organization(Ecto.UUID.t()) :: :past_due | :expired | nil
  def notice_for_organization(organization_id) do
    case latest_status(organization_id) do
      :past_due -> :past_due
      :expired -> :expired
      _ -> nil
    end
  end

  defp latest_status(organization_id) do
    organization_id
    |> Billing.list_organization_subscriptions!(authorize?: false)
    |> List.first()
    |> case do
      %{status: status} -> status
      _ -> nil
    end
  end
end
