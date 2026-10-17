defmodule Fleetms.Billing.Payment.Changes.SetReference do
  @moduledoc """
  Generates our own unique payment reference (e.g. `PMT-x7Qb...`) on create. This
  is the idempotency key we send to the provider and match webhooks/verifications
  back on, independent of the provider's own id.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      case Ash.Changeset.get_attribute(changeset, :reference) do
        nil -> Ash.Changeset.force_change_attribute(changeset, :reference, generate())
        _ -> changeset
      end
    end)
  end

  defp generate do
    "PMT-" <> (:crypto.strong_rand_bytes(9) |> Base.url_encode64(padding: false))
  end
end
