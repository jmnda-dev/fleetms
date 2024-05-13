defmodule FleetmsWeb.UploadHandler do
  @moduledoc """
  A module for handling uploaded files in the Socket
  """
  import Phoenix.LiveView, only: [consume_uploaded_entries: 3]

  @doc """
  Stores uploaded files from the Socket to the Filesystem.

  ## Parameters
    - socket: A Phoenix LiveView Socket struct.
    - uploads_ref: An atom used as a name for uploads, as specified on the `allow_upload/3` function
    - definition: A module that implements a `Waffle.Definition` behavior
    - scope: A map or struct e.g like a `UserProfile` `Ash Resource` that contains an `id`
  """

  @spec save(
          Phoenix.LiveView.Socket.t(),
          atom(),
          Waffle.Definition.t(),
          %{id: binary()} | Ash.Resource.t()
        ) ::
          list()
  def save(socket, uploads_ref, definition, scope) do
    consume_uploaded_entries(socket, uploads_ref, fn %{path: path}, entry ->
      file_extenstion = ext(entry)

      new_filename =
        Ecto.UUID.generate()
        |> String.replace("-", "")

      definition.store({%{path: path, filename: "#{new_filename}.#{file_extenstion}"}, scope})
    end)
  end

  defp ext(entry) do
    [ext | _] = MIME.extensions(entry.client_type)
    ext
  end
end
