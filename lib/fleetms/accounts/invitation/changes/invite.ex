defmodule Fleetms.Accounts.Invitation.Changes.Invite do
  @moduledoc """
  Sets up a new invitation: generates the single-use token (storing only its
  hash), sets the expiry, and emails the link after the transaction commits.

  The plain token and organization name are captured in this change's closure, so
  they never need to be persisted or threaded through context.
  """
  use Ash.Resource.Change

  alias Fleetms.Accounts.Invitation.Changes.GenerateToken
  alias Fleetms.Accounts.Invitation.Senders.SendInvitationEmail

  @token_bytes 32
  @ttl_days 7

  @impl true
  def change(changeset, _opts, _context) do
    token = @token_bytes |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
    org_name = Ash.Changeset.get_argument(changeset, :organization_name)
    expires_at = DateTime.add(DateTime.utc_now(), @ttl_days, :day)

    changeset
    |> Ash.Changeset.force_change_attribute(:hashed_token, GenerateToken.hash(token))
    |> Ash.Changeset.force_change_attribute(:expires_at, expires_at)
    |> Ash.Changeset.after_transaction(fn
      _changeset, {:ok, invitation} ->
        SendInvitationEmail.send(invitation, token, org_name)
        {:ok, invitation}

      _changeset, other ->
        other
    end)
  end
end
