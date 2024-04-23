defmodule Fleetms.Repo do
  use Ecto.Repo,
    otp_app: :fleetms,
    adapter: Ecto.Adapters.Postgres
end
