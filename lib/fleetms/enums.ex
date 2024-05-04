defmodule Fleetms.Enums do
  @moduledoc """
  Defines Enums to be used in the resources and liveviews.
  """

  @doc false
  def user_statuses do
    [
      :active,
      :inactive
    ]
  end

  @doc false
  def basic_user_roles do
    [
      :admin,
      :fleet_manager,
      :technician,
      :driver,
      :viewer
    ]
  end
end
