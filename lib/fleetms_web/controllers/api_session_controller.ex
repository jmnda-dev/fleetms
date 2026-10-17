defmodule FleetmsWeb.ApiSessionController do
  @moduledoc """
  Token login for the JSON:API: `POST /api/v1/sign-in` with an email and password
  returns a bearer JWT plus the organizations the user belongs to, so the client
  knows which `public_id` to send in the `x-organization` tenant header. An
  alternative to a long-lived API key for interactive/user-driven clients.
  """
  use FleetmsWeb, :controller

  def create(conn, params) do
    email = params["email"]
    password = params["password"]

    with true <- is_binary(email) and is_binary(password),
         {:ok, user} <-
           Fleetms.Accounts.User
           |> Ash.Query.for_read(:sign_in_with_password, %{email: email, password: password})
           |> Ash.read_one(authorize?: false) do
      conn
      |> put_status(:ok)
      |> json(%{
        token: user.__metadata__.token,
        token_type: "Bearer",
        user_id: user.id,
        organizations: organizations(user)
      })
    else
      _ -> error(conn, 401, "Invalid email or password.")
    end
  rescue
    _ -> error(conn, 401, "Invalid email or password.")
  end

  # The active memberships for the user — each `public_id` is what goes in the
  # `x-organization` header. Suspended memberships are omitted (can't be used).
  defp organizations(user) do
    user
    |> Ash.load!([user_organizations: [:organization]], actor: user)
    |> Map.get(:user_organizations, [])
    |> Enum.filter(&(&1.status == :active and not is_nil(&1.organization)))
    |> Enum.map(fn membership ->
      {_, permissions} = Fleetms.Permissions.UserCache.get_or_load(user.id, membership.organization)
      %{
        id: membership.organization.id,
        public_id: membership.organization.public_id,
        name: membership.organization.name,
        owner: membership.owner?,
        permissions: MapSet.to_list(permissions)
      }
    end)
  end

  defp error(conn, status, detail) do
    conn
    |> put_status(status)
    |> json(%{errors: [%{status: to_string(status), detail: detail}]})
  end
end
