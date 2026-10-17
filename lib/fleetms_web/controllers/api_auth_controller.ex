defmodule FleetmsWeb.ApiAuthController do
  use FleetmsWeb, :controller

  def register(conn, params) do
    strategy = AshAuthentication.Info.strategy!(Fleetms.Accounts.User, :password)

    case AshAuthentication.Strategy.action(strategy, :register, params) do
      {:ok, _user} ->
        conn
        |> put_status(:ok)
        |> json(%{message: "Registration successful. Please log in."})

      {:error, _error} ->
        error(conn, 400, "Registration failed or invalid parameters.")
    end
  end

  def request_password_reset(conn, params) do
    strategy = AshAuthentication.Info.strategy!(Fleetms.Accounts.User, :password)

    case AshAuthentication.Strategy.action(strategy, :request_password_reset, params) do
      :ok ->
        conn
        |> put_status(:ok)
        |> json(%{message: "Password reset instructions sent."})

      {:error, _error} ->
        error(conn, 400, "Failed to request password reset.")
    end
  end

  def reset_password(conn, params) do
    strategy = AshAuthentication.Info.strategy!(Fleetms.Accounts.User, :password)

    case AshAuthentication.Strategy.action(strategy, :reset, params) do
      {:ok, _user} ->
        conn
        |> put_status(:ok)
        |> json(%{message: "Password reset successful. Please log in."})

      {:error, _error} ->
        error(conn, 400, "Failed to reset password. Invalid or expired token.")
    end
  end

  defp error(conn, status, detail) do
    conn
    |> put_status(status)
    |> json(%{errors: [%{status: to_string(status), detail: detail}]})
  end
end
