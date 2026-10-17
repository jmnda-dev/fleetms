defmodule Fleetms.Accounts.UserIdentityTest do
  use Fleetms.DataCase, async: true

  alias Fleetms.Accounts.User

  defp create_username_user(username, password \\ "password1234") do
    User
    |> Ash.Changeset.for_create(:create_member_with_username, %{
      username: username,
      password: password,
      password_confirmation: password,
      profile: %{first_name: "Test"}
    })
    |> Ash.create!(authorize?: false)
  end

  describe "username" do
    test "a user can be created with a username and no email" do
      username = "driver_#{System.unique_integer([:positive])}"
      user = create_username_user(username)

      assert user.username == username
      assert is_nil(user.email)
      # Admin-provisioned users are auto-confirmed.
      refute is_nil(user.confirmed_at)
      assert user.profile.first_name == "Test"
    end

    test "username must be unique when present" do
      username = "driver_#{System.unique_integer([:positive])}"
      create_username_user(username)

      assert_raise Ash.Error.Invalid, fn -> create_username_user(username) end
    end

    test "multiple users may have no username (NULLs are distinct)" do
      _a = user_fixture()
      _b = user_fixture()
      # No raise — two email users both have NULL usernames.
      assert true
    end
  end

  describe "username sign-in" do
    test "a username user can sign in with username + password" do
      username = "driver_#{System.unique_integer([:positive])}"
      create_username_user(username, "password1234")

      strategy = AshAuthentication.Info.strategy!(User, :username_password)

      assert {:ok, user} =
               AshAuthentication.Strategy.action(strategy, :sign_in, %{
                 "username" => username,
                 "password" => "password1234"
               })

      assert user.username == username
    end

    test "the wrong password is rejected" do
      username = "driver_#{System.unique_integer([:positive])}"
      create_username_user(username, "password1234")

      strategy = AshAuthentication.Info.strategy!(User, :username_password)

      assert {:error, _} =
               AshAuthentication.Strategy.action(strategy, :sign_in, %{
                 "username" => username,
                 "password" => "wrong-password"
               })
    end
  end

  describe "at-least-one identity" do
    test "a user with neither email nor username is rejected by the DB" do
      error =
        assert_raise Ash.Error.Invalid, fn ->
          Ash.Seed.seed!(User, %{hashed_password: "x"})
        end

      assert Exception.message(error) =~ "must have either an email or a username"
    end
  end
end
