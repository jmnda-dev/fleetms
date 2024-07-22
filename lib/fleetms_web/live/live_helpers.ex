defmodule FleetmsWeb.LiveHelpers do
  @moduledoc """
  Helper functions for LiveView
  """

  @doc """
  Returns a placeholder image if the image path is nil
  """
  def image_src(image_path, opts \\ []) do
    if is_nil(image_path) do
      "https://via.placeholder.com/#{opts[:width] || 200}x#{opts[:height] || 200}?text=#{opts[:text] || "Image"}"
    else
      image_path
    end
  end

  @doc """
  Renders a value for "--" if the value is nil
  """
  def render_value(nil, _field), do: "--"

  def render_value(map_or_struct, fields) when is_list(fields) do
    get_in(map_or_struct, fields)
  end

  def render_value(map_or_struct, field) do
    value = Map.get(map_or_struct, field)
    render_value(value)
  end

  def render_value(value) do
    if is_nil(value), do: "--", else: value
  end

  @doc """
  Handles the uploads of file entries
  """

  # def maybe_handle_upload(
  #       %{assigns: %{uploads: uploads}} = socket,
  #       entries_key
  #     ) do
  #   upload_entries = Map.get(uploads, entries_key)
  #
  #   cond do
  #     upload_entries == [] ->
  #       :no_entries
  #
  #     true ->
  #       case UploadHandler.save(socket, entries_key) do
  #         [] ->
  #           :no_entries
  #
  #         saved_entries ->
  #           saved_entries
  #       end
  #   end
  # end

  def active_tab_class(active) do
    if active do
      "text-blue-600 border-blue-600 dark:text-blue-300 dark:border-blue-300 hover"
    else
      "hover:text-gray-600 hover:border-gray-300 dark:hover:text-gray-300"
    end
  end

  def get_form_value(form, key) do
    AshPhoenix.Form.value(form, key)
  end

  @doc false
  def error_to_string(:too_large), do: "Too large"
  def error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
  def error_to_string(:too_many_files), do: "You have selected too many files"
end
