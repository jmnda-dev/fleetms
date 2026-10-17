defmodule FleetmsWeb.Plugs.ApiTenant do
  @moduledoc """
  Resolves the organization (tenant) for a JSON:API request from the
  `x-organization` header (an organization's `public_id`) and sets it as the Ash
  tenant, after checking the bearer-authenticated user is a member.

  Runs after `:load_from_bearer` / `:set_actor`, so `current_user` is the caller.
  A missing token, missing/unknown header, or non-membership is answered with a
  JSON:API-shaped error and the request is halted — the same membership boundary
  the web app enforces, applied to the API.
  """
  import Plug.Conn

  @header "x-organization"

  def init(opts), do: opts

  @doc """
  `on_error` for the API-key plug: swallow the "no/invalid API key" case so the
  request can still be authenticated by a JWT bearer token (or fall through to a
  401 here). Both auth methods share the `Authorization: Bearer` header.
  """
  def ignore_api_key_error(conn, _error), do: conn

  def call(conn, _opts) do
    user = conn.assigns[:current_user]

    with true <- not is_nil(user) || :unauthenticated,
         [public_id | _] when is_binary(public_id) <- get_req_header(conn, @header),
         membership when not is_nil(membership) <- find_membership(user, public_id),
         org = membership.organization,
         true <- org.status != :suspended || :suspended do
      Ash.PlugHelpers.set_tenant(conn, org)
    else
      :unauthenticated -> error(conn, 401, "Authentication required.")
      :suspended -> error(conn, 403, "This organization is suspended.")
      [] -> error(conn, 400, "Missing #{@header} header.")
      _ -> error(conn, 403, "That organization isn't available to you.")
    end
  end

  defp find_membership(user, public_id) do
    user
    |> Ash.load!([user_organizations: [:organization]], actor: user)
    |> Map.get(:user_organizations)
    |> Enum.find(&(&1.organization.public_id == public_id))
  end

  defp error(conn, status, detail) do
    body = Jason.encode!(%{errors: [%{status: to_string(status), detail: detail}]})

    conn
    |> put_resp_content_type("application/vnd.api+json")
    |> send_resp(status, body)
    |> halt()
  end
end
