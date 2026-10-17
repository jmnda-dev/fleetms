defmodule Fleetms.Permissions.Dsl.Verifier do
  @moduledoc """
  Compile-time verifier for the Permissions DSL.

  Fails the build if a declared permission references an action that does not
  exist on the resource, or if a permission name is declared more than once.
  """
  use Spark.Dsl.Verifier

  @impl true
  def verify(dsl_state) do
    permissions = Spark.Dsl.Extension.get_entities(dsl_state, [:permissions])

    if Enum.empty?(permissions) do
      :ok
    else
      action_names =
        dsl_state
        |> Ash.Resource.Info.actions()
        |> Enum.map(& &1.name)
        |> MapSet.new()

      perm_names = Enum.map(permissions, & &1.name)
      duplicate_names = perm_names -- Enum.uniq(perm_names)

      errors =
        []
        |> check_duplicate_names(duplicate_names, dsl_state)
        |> check_action_references(permissions, action_names, dsl_state)

      case errors do
        [] -> :ok
        [first | _] -> {:error, first}
      end
    end
  end

  defp check_duplicate_names(errors, [], _), do: errors

  defp check_duplicate_names(errors, dupes, dsl_state) do
    module = Spark.Dsl.Verifier.get_persisted(dsl_state, :module)

    Enum.reduce(Enum.uniq(dupes), errors, fn name, acc ->
      [
        Spark.Error.DslError.exception(
          module: module,
          message: "Permission name :#{name} is declared more than once.",
          path: [:permissions, :permission, name]
        )
        | acc
      ]
    end)
  end

  defp check_action_references(errors, permissions, action_names, dsl_state) do
    module = Spark.Dsl.Verifier.get_persisted(dsl_state, :module)

    Enum.reduce(permissions, errors, fn perm, acc ->
      actions = List.wrap(perm.action)
      missing = Enum.reject(actions, fn a -> MapSet.member?(action_names, a) end)

      Enum.reduce(missing, acc, fn missing_action, inner_acc ->
        [
          Spark.Error.DslError.exception(
            module: module,
            message:
              "Permission :#{perm.name} references action :#{missing_action} " <>
                "which does not exist on #{inspect(module)}. " <>
                "Available actions: #{Enum.map_join(action_names, ", ", &":#{&1}")}",
            path: [:permissions, :permission, perm.name]
          )
          | inner_acc
        ]
      end)
    end)
  end
end
