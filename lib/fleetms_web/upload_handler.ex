defmodule FleetmsWeb.UploadHandler do
  import Phoenix.LiveView, only: [consume_uploaded_entries: 3]
  use FleetmsWeb, :verified_routes

  def save(socket, entries_key) do
    consume_uploaded_entries(socket, entries_key, fn %{path: path}, entry ->
      dest =
        Path.join([
          :code.priv_dir(:fleetms),
          "static",
          "uploads",
          "#{Path.basename(path)}.#{ext(entry)}"
        ])

      File.cp!(path, dest)
      {:ok, ~p"/uploads/#{Path.basename(dest)}"}
    end)
  end

  def save(socket, uploads_ref, definition, scope, opts \\ []) do
    consume_uploaded_entries(socket, uploads_ref, fn %{path: path}, entry ->
      file_extenstion = ext(entry)

      new_filename =
        Ecto.UUID.generate()
        |> String.replace("-", "")

      cond do
        opts[:return_file_type] == true and opts[:return_original_filename] == true ->
          {:ok, new_filename} =
            definition.store(
              {%{path: path, filename: "#{new_filename}.#{file_extenstion}"}, scope}
            )

          file_type = ext(entry) |> String.upcase()
          original_filename = entry.client_name |> clean_filename()

          {:ok, {new_filename, original_filename, file_type}}

        true ->
          definition.store({%{path: path, filename: "#{new_filename}.#{file_extenstion}"}, scope})
      end
    end)
  end

  defp ext(entry) do
    [ext | _] = MIME.extensions(entry.client_type)
    ext
  end

  defp clean_filename(filename) do
    pattern = ~r/[^\w\-_\.]/u

    String.replace(filename, pattern, "-")
  end
end
