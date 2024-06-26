defmodule Fleetms.Repo.Migrations.AddStatusAttribute do
  @moduledoc """
  Updates resources based on their most recent snapshots.

  This file was autogenerated with `mix ash_postgres.generate_migrations`
  """

  use Ecto.Migration

  def up do
    alter table(:users) do
      add :status, :text, null: false, default: true
    end
  end

  def down do
    alter table(:users) do
      remove :status
    end
  end
end
