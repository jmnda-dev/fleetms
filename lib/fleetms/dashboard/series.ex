defmodule Fleetms.Dashboard.Series do
  @derive {Jason.Encoder, only: [:name, :color, :data, :group]}
  defstruct name: nil, color: nil, group: nil, data: []

  def new(name, opts \\ []) do
    if opts[:fuel] do
      %{
        name: name,
        data: opts[:data] || [],
        group: opts[:group] || nil
      }
    else
      %__MODULE__{
        name: name,
        color: opts[:color],
        data: opts[:data] || [],
        group: opts[:group] || nil
      }
    end
  end
end
