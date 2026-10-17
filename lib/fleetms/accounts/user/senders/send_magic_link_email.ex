defmodule Fleetms.Accounts.User.Senders.SendMagicLinkEmail do
  @moduledoc """
  Sends a magic link email
  """

  use AshAuthentication.Sender
  use FleetmsWeb, :verified_routes

  import Swoosh.Email
  alias Fleetms.Mailer

  @impl true
  def send(user_or_email, token, _) do
    # if you get a user, its for a user that already exists.
    # if you get an email, then the user does not yet exist.

    email =
      case user_or_email do
        %{email: email} -> email
        email -> email
      end

    opts = [
      title: "Sign in to FleetMS",
      intro:
        "Click the button below to sign in. This link will expire shortly for your security.",
      button_label: "Sign in",
      url: url(~p"/magic_link/#{token}")
    ]

    new()
    |> from(Fleetms.Emails.from())
    |> to(to_string(email))
    |> subject("Your login link")
    |> html_body(Fleetms.Emails.action_email(opts))
    |> text_body(Fleetms.Emails.action_email_text(opts))
    |> Mailer.deliver!()
  end
end
