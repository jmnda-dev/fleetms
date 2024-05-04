defmodule Fleetms.Repo.Migrations.AddRolesFieldToUser do
  @moduledoc """
  Updates resources based on their most recent snapshots.

  This file was autogenerated with `mix ash_postgres.generate_migrations`
  """

  use Ecto.Migration

  def up do
    alter table(:users) do
      modify :status, :text, default: "active"
      add :roles, {:array, :text}, null: false
    end
  end

  def down do
    alter table(:users) do
      remove :roles
      modify :status, :text, default: true
    end
  end
end