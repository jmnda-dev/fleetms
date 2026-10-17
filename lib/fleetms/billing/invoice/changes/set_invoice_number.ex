defmodule Fleetms.Billing.Invoice.Changes.SetInvoiceNumber do
  @moduledoc """
  Assigns a human-readable, sequential invoice number (e.g. `INV-000042`) on
  create, drawn from a public-schema Postgres sequence. Billing is not
  multi-tenant, so a single global sequence is correct.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      case Ash.Changeset.get_attribute(changeset, :number) do
        nil -> Ash.Changeset.force_change_attribute(changeset, :number, next_number())
        _ -> changeset
      end
    end)
  end

  defp next_number do
    %{rows: [[value]]} = Fleetms.Repo.query!("SELECT nextval('billing_invoices_number_seq')")
    "INV-" <> String.pad_leading(to_string(value), 6, "0")
  end
end
