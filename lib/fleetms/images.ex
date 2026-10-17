defmodule Fleetms.Images do
  @moduledoc """
  Image processing for uploads, built on `Image` (libvips via `vix`).

  libvips runs in-process — no shelling out to ImageMagick — and is fast and
  memory-light even on large photos. This module produces the derivatives the
  fleet UI needs (a square thumbnail, a bounded "display" version) and strips
  metadata (EXIF/GPS) on write so we don't leak camera location data.
  """

  @type opts :: keyword

  @doc """
  Whether `path` is a decodable raster image. Used to validate uploads before
  we trust a client-supplied content type.
  """
  @spec image?(Path.t()) :: boolean
  def image?(path) do
    match?({:ok, _}, Image.open(path, access: :sequential))
  end

  @doc """
  Returns `{:ok, %{width, height}}` for `path`, or `{:error, reason}`.
  """
  @spec info(Path.t()) :: {:ok, map} | {:error, term}
  def info(path) do
    with {:ok, image} <- Image.open(path, access: :sequential) do
      {:ok, %{width: Image.width(image), height: Image.height(image)}}
    end
  end

  @doc """
  Writes a square, center-/attention-cropped thumbnail of `source` to `dest`.

  Options:
    * `:size` — edge length in px (default `300`)
    * `:quality` — JPEG/WebP quality (default `80`)
  """
  @spec thumbnail(Path.t(), Path.t(), opts) :: {:ok, Path.t()} | {:error, term}
  def thumbnail(source, dest, opts \\ []) do
    size = Keyword.get(opts, :size, 300)
    quality = Keyword.get(opts, :quality, 80)

    with {:ok, image} <- Image.thumbnail(source, size, crop: :attention),
         {:ok, _} <- Image.write(image, dest, strip_metadata: true, quality: quality) do
      {:ok, dest}
    end
  end

  @doc """
  Writes a metadata-stripped copy of `source` to `dest`, bounded so neither
  dimension exceeds `:max` (default `1600`) px while preserving aspect ratio.
  Smaller images are passed through (only re-encoded/stripped, never upscaled).

  Options:
    * `:max` — longest-edge bound in px (default `1600`)
    * `:quality` — JPEG/WebP quality (default `82`)
  """
  @spec display(Path.t(), Path.t(), opts) :: {:ok, Path.t()} | {:error, term}
  def display(source, dest, opts \\ []) do
    max = Keyword.get(opts, :max, 1600)
    quality = Keyword.get(opts, :quality, 82)

    # `resize: :down` only ever shrinks, so a small source is passed through at
    # its original size rather than being upscaled.
    with {:ok, image} <- Image.thumbnail(source, max, resize: :down),
         {:ok, _} <- Image.write(image, dest, strip_metadata: true, quality: quality) do
      {:ok, dest}
    end
  end
end
