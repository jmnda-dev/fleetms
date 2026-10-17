defmodule Fleetms.Repo.Migrations.CreateFeatureFlagsTable do
  @moduledoc """
  The FunWithFlags Ecto store (see config :fun_with_flags, :persistence). Copied
  from the library's default migration; keep the table name in sync with the
  `:ecto_table_name` config (default `fun_with_flags_toggles`).
  """
  use Ecto.Migration

  def up do
    create table(:fun_with_flags_toggles, primary_key: false) do
      add :id, :bigserial, primary_key: true
      add :flag_name, :string, null: false
      add :gate_type, :string, null: false
      add :target, :string, null: false
      add :enabled, :boolean, null: false
    end

    create index(:fun_with_flags_toggles, [:flag_name, :gate_type, :target],
             unique: true,
             name: "fwf_flag_name_gate_target_idx"
           )
  end

  def down do
    drop table(:fun_with_flags_toggles)
  end
end
