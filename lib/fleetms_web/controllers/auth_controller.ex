defmodule FleetmsWeb.AuthController do
  @moduledoc """
  The AuthController module.
  """
  use FleetmsWeb, :controller
  use AshAuthentication.Phoenix.Controller

  def success(conn, _activity, user, _token) do
    return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> delete_session(:return_to)
    |> store_in_session(user)
    |> assign(:current_user, user)
    |> redirect(to: return_to)
  end

  def failure(
        conn,
        _activity,
        _reason
      ) do
    conn
    |> put_flash(
      :error,
      "Username or password is incorrect"
    )
    |> redirect(to: "/sign-in")
  end

  def sign_out(conn, _params) do
    return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> clear_session()
    |> redirect(to: return_to)
  end
end
