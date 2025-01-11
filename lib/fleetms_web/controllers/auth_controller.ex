defmodule FleetmsWeb.AuthController do
  use FleetmsWeb, :controller
  use AshAuthentication.Phoenix.Controller

  def success(conn, _activity, user, _token) do
    return_to = get_session(conn, :return_to) || ~p"/"
    user = Ash.load!(user, :organization)

    conn
    |> delete_session(:return_to)
    |> store_in_session(user)
    |> maybe_put_tenant_in_session(user)
    |> assign(:current_user, user)
    |> redirect(to: return_to)
  end

  def failure(
        conn,
        _activity,
        _reason
      ) do
    conn
    |> LiveToast.put_toast(
      :error,
      "Email or password is incorrect"
    )
    |> redirect(to: "/sign-in")
  end

  def sign_out(conn, _params) do
    return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> clear_session()
    |> redirect(to: return_to)
  end

  defp maybe_put_tenant_in_session(conn, nil), do: conn

  defp maybe_put_tenant_in_session(conn, user) do
    put_session(conn, :tenant, Ash.ToTenant.to_tenant(user.organization, user.organization))
  end
end
