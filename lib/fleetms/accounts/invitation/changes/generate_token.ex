defmodule Fleetms.Accounts.Invitation.Changes.GenerateToken do
  @moduledoc """
  Generates a single-use invitation token. Only the SHA-256 hash is stored; the
  plain token is stashed in changeset context so the sender can email it, and is
  never persisted.
  """
  use Ash.Resource.Change

  @byte_length 32

  @impl true
  def change(changeset, _opts, _context) do
    token = @byte_length |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)

    changeset
    |> Ash.Changeset.force_change_attribute(:hashed_token, hash(token))
    |> Ash.Changeset.put_context(:plain_token, token)
  end

  @doc "Hashes a plain invitation token for storage/lookup."
  def hash(token) do
    :sha256 |> :crypto.hash(token) |> Base.encode16(case: :lower)
  end
end
