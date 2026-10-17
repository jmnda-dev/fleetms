defmodule Fleetms.Accounts.ConfirmationTest do
  use Fleetms.DataCase, async: true

  import Swoosh.TestAssertions

  alias AshAuthentication.Errors.UnconfirmedUser
  alias Fleetms.Accounts.User

  defp register(email) do
    User
    |> Ash.Changeset.for_create(:register_with_password, %{
      email: email,
      password: "password1234",
      password_confirmation: "password1234"
    })
    |> Ash.create!(authorize?: false)
  end

  defp sign_in(email, password \\ "password1234") do
    strategy = AshAuthentication.Info.strategy!(User, :password)
    AshAuthentication.Strategy.action(strategy, :sign_in, %{"email" => email, "password" => password})
  end

  describe "email confirmation" do
    test "registering a user sends a confirmation email" do
      email = "confirm-#{System.unique_integer([:positive])}@example.com"
      register(email)

      assert_email_sent(fn sent ->
        sent.subject == "Confirm your email address" and
          {"", email} in sent.to
      end)
    end

    test "a newly registered user is unconfirmed" do
      user = register("confirm-#{System.unique_integer([:positive])}@example.com")
      assert is_nil(user.confirmed_at)
    end

    test "an unconfirmed user cannot sign in" do
      email = "confirm-#{System.unique_integer([:positive])}@example.com"
      register(email)

      assert {:error, error} = sign_in(email)
      assert unconfirmed_error?(error)
    end

    test "a confirmed user can sign in" do
      email = "confirm-#{System.unique_integer([:positive])}@example.com"
      user = register(email)
      Ash.Seed.update!(user, %{confirmed_at: DateTime.utc_now()})

      assert {:ok, signed_in} = sign_in(email)
      assert to_string(signed_in.email) == email
    end

    test "the wrong password is rejected even for a confirmed user" do
      email = "confirm-#{System.unique_integer([:positive])}@example.com"
      user = register(email)
      Ash.Seed.update!(user, %{confirmed_at: DateTime.utc_now()})

      assert {:error, error} = sign_in(email, "wrong-password")
      refute unconfirmed_error?(error)
    end
  end

  defp unconfirmed_error?(%UnconfirmedUser{}), do: true
  defp unconfirmed_error?(%{caused_by: caused_by}) when not is_nil(caused_by),
    do: unconfirmed_error?(caused_by)

  defp unconfirmed_error?(%{errors: errors}) when is_list(errors),
    do: Enum.any?(errors, &unconfirmed_error?/1)

  defp unconfirmed_error?(_), do: false
end
