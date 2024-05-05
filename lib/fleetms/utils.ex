defmodule Fleetms.Utils do
  @moduledoc """
  This modules contains utility/helper functions used the Elixir code of this project.
  """

  @doc """
  Converts a list of atoms into a Keyword list that can be used for example, in HTML select inputs.

  ## Examples
      iex> atom_list_to_options_for_select([:due_for_service, :upcoming, :overdue])
      [
        {"Due For Service", :due_for_service},
        {"Upcoming", :upcoming},
        {"Overdue", :overdue}
      ]
  """
  def atom_list_to_options_for_select(list) do
    Enum.map(list, &{humanize_string(&1), &1})
  end

  @doc """
  Humanizes a string

  ## Examples
      iex> humanize_string(:due_for_service)
      "Due For Service"

      iex> humanize_string("due_for_service")
      "Due For Service"
  """
  def humanize_string(string) when is_atom(string) do
    string
    |> Atom.to_string()
    |> humanize_string()
  end

  def humanize_string(string) do
    new_string =
      string
      |> String.replace(~r/_/, " ")
      |> String.split()
      |> Enum.map(&String.capitalize(&1))
      |> Enum.join(" ")

    new_string
  end
end
