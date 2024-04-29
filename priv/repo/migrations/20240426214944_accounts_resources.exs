defmodule Fleetms.Repo.Migrations.AccountsResources do
  @moduledoc """
  Updates resources based on their most recent snapshots.

  This file was autogenerated with `mix ash_postgres.generate_migrations`
  """

  use Ecto.Migration

  def up do
    create table(:users, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :email, :citext, null: false
      add :username, :text
      add :hashed_password, :text, null: false

      add :created_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :organization_id, :uuid, null: false
    end

    create table(:user_profiles, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
      add :first_name, :text, null: false
      add :last_name, :text
      add :other_name, :text
      add :address, :text
      add :city, :text
      add :state, :text
      add :postal_code, :text

      add :created_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :user_id,
          references(:users,
            column: :id,
            name: "user_profiles_user_id_fkey",
            type: :uuid,
            prefix: "public"
          ),
          null: false
    end

    create unique_index(:user_profiles, [:user_id],
             name: "user_profiles_unique_user_profile_index"
           )

    create table(:tokens, primary_key: false) do
      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :created_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :extra_data, :map
      add :purpose, :text, null: false
      add :expires_at, :utc_datetime, null: false
      add :subject, :text, null: false
      add :jti, :text, null: false, primary_key: true
    end

    create table(:organizations, primary_key: false) do
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()"), primary_key: true
    end

    alter table(:users) do
      modify :organization_id,
             references(:organizations,
               column: :id,
               name: "users_organization_id_fkey",
               type: :uuid,
               prefix: "public"
             )
    end

    create unique_index(:users, [:email], name: "users_unique_email_index")

    create unique_index(:users, [:username], name: "users_unique_username_index")

    alter table(:organizations) do
      add :name, :text, null: false
      add :phone_number, :text

      add :created_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")

      add :updated_at, :utc_datetime_usec,
        null: false,
        default: fragment("(now() AT TIME ZONE 'utc')")
    end
  end

  def down do
    alter table(:organizations) do
      remove :updated_at
      remove :created_at
      remove :phone_number
      remove :name
    end

    drop_if_exists unique_index(:users, [:username], name: "users_unique_username_index")

    drop_if_exists unique_index(:users, [:email], name: "users_unique_email_index")

    drop constraint(:users, "users_organization_id_fkey")

    alter table(:users) do
      modify :organization_id, :uuid
    end

    drop table(:organizations)

    drop table(:tokens)

    drop_if_exists unique_index(:user_profiles, [:user_id],
                     name: "user_profiles_unique_user_profile_index"
                   )

    drop constraint(:user_profiles, "user_profiles_user_id_fkey")

    drop table(:user_profiles)

    drop table(:users)
  end
end
