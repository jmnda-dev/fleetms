defmodule FleetmsWeb.AuthController do
  use FleetmsWeb, :controller
  use AshAuthentication.Phoenix.Controller

  def success(conn, activity, user, _token) do
    return_to = get_session(conn, :return_to) || ~p"/"

    message =
      case activity do
        {:confirm_new_user, :confirm} -> "Your email address has now been confirmed"
        {:password, :reset} -> "Your password has successfully been reset"
        _ -> "You are now signed in"
      end

    conn
    |> delete_session(:return_to)
    |> store_in_session(user)
    # If your resource has a different name, update the assign name here (i.e :current_admin)
    |> assign(:current_user, user)
    |> put_flash(:info, message)
    |> redirect(to: return_to)
  end

  # Registration succeeds at the DB level but the follow-up sign-in is blocked by
  # the confirmation gate. That's the intended flow — surface it as a friendly
  # "check your email" notice rather than an error.
  def failure(conn, {:password, :register}, reason) do
    if unconfirmed_user?(reason) do
      conn
      |> delete_session(:return_to)
      |> put_flash(
        :info,
        "Account created. Check your email for a confirmation link, then sign in."
      )
      |> redirect(to: ~p"/sign-in")
    else
      do_failure(conn, reason)
    end
  end

  def failure(conn, _activity, reason), do: do_failure(conn, reason)

  defp do_failure(conn, reason) do
    message =
      cond do
        match?(
          %AshAuthentication.Errors.AuthenticationFailed{
            caused_by: %Ash.Error.Forbidden{
              errors: [%AshAuthentication.Errors.CannotConfirmUnconfirmedUser{}]
            }
          },
          reason
        ) ->
          """
          You have already signed in another way, but have not confirmed your account.
          You can confirm your account using the link we sent to you, or by resetting your password.
          """

        unconfirmed_user?(reason) ->
          """
          Please confirm your email address before signing in.
          Use the confirmation link we emailed you, or reset your password to confirm.
          """

        true ->
          "Incorrect email or password"
      end

    conn
    |> put_flash(:error, message)
    |> redirect(to: ~p"/sign-in")
  end

  # A blocked sign-in (require_confirmed_with) surfaces as an AuthenticationFailed
  # whose `caused_by` is an UnconfirmedUser, either directly or nested inside a
  # wrapper error's `errors` list.
  defp unconfirmed_user?(%AshAuthentication.Errors.AuthenticationFailed{caused_by: caused_by}),
    do: unconfirmed_user?(caused_by)

  defp unconfirmed_user?(%AshAuthentication.Errors.UnconfirmedUser{}), do: true

  defp unconfirmed_user?(%{errors: errors}) when is_list(errors),
    do: Enum.any?(errors, &unconfirmed_user?/1)

  defp unconfirmed_user?(_), do: false

  def sign_out(conn, _params) do
    return_to = get_session(conn, :return_to) || ~p"/"

    conn
    |> clear_session(:fleetms)
    |> put_flash(:info, "You are now signed out")
    |> redirect(to: return_to)
  end
end
