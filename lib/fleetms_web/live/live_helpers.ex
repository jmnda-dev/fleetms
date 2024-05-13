defmodule FleetmsWeb.LiveHelpers do
  @moduledoc """
  Helper functions for LiveView
  """

  @doc false
  def error_to_string(:too_large), do: "Too large"
  def error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
  def error_to_string(:too_many_files), do: "You have selected too many files"
end
