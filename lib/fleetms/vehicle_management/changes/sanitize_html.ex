defmodule Fleetms.VehicleManagement.Changes.SanitizeHtml do
  @moduledoc """
  Sanitizes rich-text (WYSIWYG) attributes before they are stored.

      change {Fleetms.VehicleManagement.Changes.SanitizeHtml, attributes: [:notes]}

  The editor produces HTML on the client, which is untrusted. This scrubs each
  listed attribute through `Fleetms.Html.sanitize/1` whenever it's being changed,
  so stored markup is always safe to render with `raw/1`.
  """
  use Ash.Resource.Change

  @impl true
  def init(opts) do
    case opts[:attributes] do
      attrs when is_list(attrs) and attrs != [] -> {:ok, opts}
      _ -> {:error, "attributes must be a non-empty list"}
    end
  end

  @impl true
  def change(changeset, opts, _context) do
    Enum.reduce(opts[:attributes], changeset, fn attribute, changeset ->
      case Ash.Changeset.fetch_change(changeset, attribute) do
        {:ok, value} ->
          Ash.Changeset.force_change_attribute(changeset, attribute, Fleetms.Html.sanitize(value))

        :error ->
          changeset
      end
    end)
  end
end
