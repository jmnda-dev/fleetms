defmodule Fleetms.Accounts.User.Validations.ValidateCurrentPassword do
  use Ash.Resource.Validation
  alias Ash.Error.Changes.InvalidArgument
  alias Fleetms.Accounts.User

  @impl true
  def validate(changeset, _opts, _context) do
    hashed = Ash.Changeset.get_data(changeset, :hashed_password)

    with {:ok, strategy} <- AshAuthentication.Info.strategy(User, :password),
         value when is_binary(value) <-
           Ash.Changeset.get_argument(changeset, :current_password),
         true <- strategy.hash_provider.valid?(value, hashed) do
      :ok
    else
      _error ->
        {:error, InvalidArgument.exception(field: :current_password, message: "Wrong password")}
    end
  end
end
