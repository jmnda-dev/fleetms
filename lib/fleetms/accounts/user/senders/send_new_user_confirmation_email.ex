defmodule Fleetms.Accounts.User.Senders.SendNewUserConfirmationEmail do
  @moduledoc """
  Sends an email for a new user to confirm their email address.
  """

  use AshAuthentication.Sender
  use FleetmsWeb, :verified_routes

  import Swoosh.Email

  alias Fleetms.Mailer

  @impl true
  def send(user, token, _) do
    opts = [
      title: "Confirm your email",
      intro:
        "Welcome to FleetMS! Please confirm your email address to finish setting up your account.",
      button_label: "Confirm email",
      url: url(~p"/confirm_new_user/#{token}")
    ]

    new()
    |> from(Fleetms.Emails.from())
    |> to(to_string(user.email))
    |> subject("Confirm your email address")
    |> html_body(Fleetms.Emails.action_email(opts))
    |> text_body(Fleetms.Emails.action_email_text(opts))
    |> Mailer.deliver!()
  end
end
