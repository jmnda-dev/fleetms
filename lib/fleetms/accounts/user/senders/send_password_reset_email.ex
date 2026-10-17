defmodule Fleetms.Accounts.User.Senders.SendPasswordResetEmail do
  @moduledoc """
  Sends a password reset email
  """

  use AshAuthentication.Sender
  use FleetmsWeb, :verified_routes

  import Swoosh.Email

  alias Fleetms.Mailer

  @impl true
  def send(user, token, _) do
    opts = [
      title: "Reset your password",
      intro:
        "We received a request to reset your FleetMS password. Click below to choose a new one.",
      button_label: "Reset password",
      url: url(~p"/password-reset/#{token}"),
      note: "If you didn't request this, no action is needed — your password stays the same."
    ]

    new()
    |> from(Fleetms.Emails.from())
    |> to(to_string(user.email))
    |> subject("Reset your password")
    |> html_body(Fleetms.Emails.action_email(opts))
    |> text_body(Fleetms.Emails.action_email_text(opts))
    |> Mailer.deliver!()
  end
end
