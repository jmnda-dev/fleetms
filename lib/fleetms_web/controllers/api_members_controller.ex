defmodule FleetmsWeb.ApiMembersController do
  @moduledoc """
  Manage who belongs to the current organization over the API: list members, add
  one by email, and suspend / reactivate / remove one.

  Membership spans the public schema (`User`, `UserOrganization`) and the tenant
  schema (`UserRole`), so — like the web app — every action delegates to
  `Fleetms.Membership`, the authoritative authorization gate. The acting user is
  the bearer-authenticated `current_user`; the organization is the tenant resolved
  from the `x-organization` header by `FleetmsWeb.Plugs.ApiTenant`.

  This is a plain controller rather than an AshJsonApi route because
  `UserOrganization` has no authorizer and isn't itself multitenant (it's keyed by
  `organization_id`, not schema), so exposing it directly would leak every org's
  members. Responses still follow the JSON:API `data` shape for consistency.
  """
  use FleetmsWeb, :controller

  alias Fleetms.Accounts.UserOrganization
  alias Fleetms.Membership

  require Ash.Query

  # GET /api/v1/members
  def index(conn, _params) do
    with {actor, org} <- context(conn),
         {:ok, memberships} <- Membership.list_members(org, actor) do
      json(conn, %{data: Enum.map(memberships, &member_resource/1)})
    else
      error -> render_error(conn, error)
    end
  end

  # POST /api/v1/members  {"email": "...", "role_id": "..."}
  def create(conn, params) do
    with {actor, org} <- context(conn),
         true <- is_binary(params["email"]) || :bad_request,
         attrs <- %{email: params["email"], role_id: params["role_id"]},
         {:ok, kind, record} <- Membership.invite_member(attrs, org, actor) do
      conn
      |> put_status(:created)
      |> json(%{data: added_or_invited(kind, record)})
    else
      error -> render_error(conn, error)
    end
  end

  # DELETE /api/v1/members/:id
  def delete(conn, %{"id" => id}) do
    with {actor, org} <- context(conn),
         {:ok, membership} <- fetch_membership(id, org),
         {:ok, _} <- Membership.remove_member(membership, org, actor) do
      send_resp(conn, :no_content, "")
    else
      error -> render_error(conn, error)
    end
  end

  # POST /api/v1/members/:id/suspend
  def suspend(conn, %{"id" => id}) do
    transition(conn, id, &Membership.suspend_member/3)
  end

  # POST /api/v1/members/:id/reactivate
  def reactivate(conn, %{"id" => id}) do
    transition(conn, id, &Membership.reactivate_member/3)
  end

  defp transition(conn, id, fun) do
    with {actor, org} <- context(conn),
         {:ok, membership} <- fetch_membership(id, org),
         {:ok, updated} <- fun.(membership, org, actor) do
      json(conn, %{data: member_resource(reload(updated, org))})
    else
      error -> render_error(conn, error)
    end
  end

  # --- helpers ---

  defp context(conn) do
    case {conn.assigns[:current_user], Ash.PlugHelpers.get_tenant(conn)} do
      {%{} = actor, %{} = org} -> {actor, org}
      _ -> :unauthenticated
    end
  end

  # Only a membership belonging to the current tenant org is addressable, so a
  # client can never act on another organization's members by guessing an id.
  defp fetch_membership(id, org) do
    UserOrganization
    |> Ash.Query.filter(id == ^id and organization_id == ^org.id)
    |> Ash.Query.load(user: [:profile])
    |> Ash.read_one(authorize?: false)
    |> case do
      {:ok, nil} -> :not_found
      {:ok, membership} -> {:ok, membership}
      _ -> :not_found
    end
  end

  defp reload(%UserOrganization{id: id}, org) do
    {:ok, membership} = fetch_membership(id, org)
    membership
  end

  defp added_or_invited(:added, membership), do: member_resource(membership)

  defp added_or_invited(:invited, invitation) do
    %{
      type: "invitation",
      id: invitation.id,
      attributes: %{email: to_string(invitation.email), status: "invited"}
    }
  end

  defp member_resource(%UserOrganization{} = m) do
    %{
      type: "member",
      id: m.id,
      attributes: %{
        user_id: m.user_id,
        status: to_string(m.status),
        owner: m.owner?,
        email: email(m.user),
        first_name: profile_field(m.user, :first_name),
        last_name: profile_field(m.user, :last_name)
      }
    }
  end

  defp email(%{email: email}) when not is_nil(email), do: to_string(email)
  defp email(_), do: nil

  defp profile_field(%{profile: %{} = profile}, field), do: Map.get(profile, field)
  defp profile_field(_, _), do: nil

  defp render_error(conn, :unauthenticated), do: error(conn, 401, "Authentication required.")
  defp render_error(conn, :bad_request), do: error(conn, 400, "An email is required.")
  defp render_error(conn, :not_found), do: error(conn, 404, "That member was not found.")

  defp render_error(conn, {:error, :forbidden}),
    do: error(conn, 403, "You can't manage members here.")

  defp render_error(conn, {:error, {:cannot, what}}),
    do: error(conn, 422, "You can't #{what}.")

  defp render_error(conn, {:error, %Ash.Error.Forbidden{}}),
    do: error(conn, 403, "You can't manage members here.")

  defp render_error(conn, {:error, %Ash.Error.Invalid{} = err}),
    do: error(conn, 422, Exception.message(err))

  defp render_error(conn, _), do: error(conn, 422, "The request could not be completed.")

  defp error(conn, status, detail) do
    conn
    |> put_status(status)
    |> json(%{errors: [%{status: to_string(status), detail: detail}]})
  end
end
