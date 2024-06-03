defmodule Fleetms.VehiclePhoto do
  use Waffle.Definition

  # Include ecto support (requires package waffle_ecto installed):
  # use Waffle.Ecto.Definition

  @versions [:original]

  # To add a thumbnail version:
  @versions [:original, :thumb]

  # Override the bucket on a per definition basis:
  # def bucket do
  #   :custom_bucket_name
  # end

  # def bucket({_file, scope}) do
  #   scope.bucket || bucket()
  # end

  # Whitelist file extensions:
  # def validate({file, _}) do
  #   file_extension = file.file_name |> Path.extname() |> String.downcase()
  #
  #   case Enum.member?(~w(.jpg .jpeg .gif .png), file_extension) do
  #     true -> :ok
  #     false -> {:error, "invalid file type"}
  #   end
  # end

  # Define a thumbnail transformation:
  def transform(:thumb, _) do
    {:convert, "-strip -thumbnail 250x250^ -gravity center -extent 250x250 -format jpg", :jpg}
  end

  def transform(:original, _) do
    {:convert, "-format jpg", :jpg}
  end

  # Override the persisted filenames:
  def filename(:thumb, {%{file_name: filename} = _file, _scope}) do
    "th_" <> filename
  end

  def filename(:original, {%{file_name: filename} = _file, _scope}) do
    "og_" <> filename
  end

  # Override the storage directory:
  def storage_dir(_version, {_file, scope}) do
    "uploads/vehicle/photos/#{scope.id}"
  end

  # Provide a default URL if there hasn't been a file uploaded
  def default_url(_version, _scope) do
    "https://via.placeholder.com/250x250?text=No+Photo"
  end

  # Specify custom headers for s3 objects
  # Available options are [:cache_control, :content_disposition,
  #    :content_encoding, :content_length, :content_type,
  #    :expect, :expires, :storage_class, :website_redirect_location]
  #
  # def s3_object_headers(version, {file, scope}) do
  #   [content_type: MIME.from_path(file.file_name)]
  # end
end
