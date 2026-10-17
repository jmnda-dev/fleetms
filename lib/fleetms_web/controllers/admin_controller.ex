defmodule FleetmsWeb.AdminController do
  @moduledoc """
  Platform-admin actions that need to write the session (which LiveViews can't do
  directly): entering and leaving "manage an individual client" mode.

  Entering stashes the chosen client's `owner_id` in the session as
  `:pool_acting_as` and drops the staff member into the individuals pool. From
  there `FleetmsWeb.LiveUserAuth` scopes the session to that client (their fleet
  only) via `Fleetms.Scope.on_behalf_of`. Staff-only (`is_super_admin`).
  """
  use FleetmsWeb, :controller

  alias Fleetms.{Accounts, Individuals}

  def enter_individual(conn, %{"owner_id" => owner_id}) do
    user = conn.assigns[:current_user]

    cond do
      is_nil(user) or not user.is_super_admin ->
        conn
        |> put_flash(:error, "You don't have access to that.")
        |> redirect(to: ~p"/sign-in")

      not Fleetms.FeatureFlags.individual_registration?() ->
        conn
        |> put_flash(:error, "Individual client registration is disabled.")
        |> redirect(to: ~p"/admin")

      not individual_client?(owner_id, user) ->
        conn
        |> put_flash(:error, "That client could not be found.")
        |> redirect(to: ~p"/admin/individuals")

      true ->
        conn
        |> put_session(:pool_acting_as, owner_id)
        |> redirect(to: ~p"/o/#{Individuals.find_pool()}")
    end
  end

  def exit_individual(conn, _params) do
    conn
    |> delete_session(:pool_acting_as)
    |> redirect(to: ~p"/admin/individuals")
  end

  defp individual_client?(owner_id, user) do
    case Accounts.get_client_profile_for_owner(owner_id, actor: user, not_found_error?: false) do
      {:ok, %Accounts.ClientProfile{}} -> true
      _ -> false
    end
  end
end
