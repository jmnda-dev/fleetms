defmodule Fleetms.Accounts.Organization.Changes.GeneratePublicId do
  @moduledoc """
  Generates the organization's immutable, opaque `public_id` on creation.

  The `public_id` is what appears in URLs (`/o/<public_id>/...`) — it is short,
  fixed-length, collision-free (guarded by the `unique_public_id` identity) and
  NOT derived from the name, so renaming an organization never breaks links and
  the company name is not leaked in the URL.
  """
  use Ash.Resource.Change

  # 8 random bytes -> 13 base32 chars; we keep 12 lowercase alphanumeric-ish
  # chars (Crockford-ish a–z2–7). 40 bits of entropy is ample for this scale.
  @byte_length 8
  @id_length 12

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.force_change_attribute(changeset, :public_id, generate())
  end

  defp generate do
    @byte_length
    |> :crypto.strong_rand_bytes()
    |> Base.encode32(case: :lower, padding: false)
    |> binary_part(0, @id_length)
  end
end
