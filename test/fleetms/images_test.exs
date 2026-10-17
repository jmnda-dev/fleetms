defmodule Fleetms.ImagesTest do
  use ExUnit.Case, async: true

  alias Fleetms.Images

  setup do
    dir = Path.join(System.tmp_dir!(), "fleetms_images_#{System.unique_integer([:positive])}")
    File.mkdir_p!(dir)
    on_exit(fn -> File.rm_rf!(dir) end)

    # A 1200x800 source image written to disk.
    source = Path.join(dir, "source.png")
    Image.new!(1200, 800, color: [20, 120, 200]) |> Image.write!(source)

    %{dir: dir, source: source}
  end

  test "image?/1 distinguishes images from non-images", %{source: source, dir: dir} do
    assert Images.image?(source)

    not_image = Path.join(dir, "notes.txt")
    File.write!(not_image, "just text")
    refute Images.image?(not_image)
  end

  test "info/1 reports dimensions", %{source: source} do
    assert {:ok, %{width: 1200, height: 800}} = Images.info(source)
  end

  test "thumbnail/3 writes a square, downscaled image", %{source: source, dir: dir} do
    dest = Path.join(dir, "thumb.jpg")
    assert {:ok, ^dest} = Images.thumbnail(source, dest, size: 200)
    assert {:ok, %{width: 200, height: 200}} = Images.info(dest)
  end

  test "display/3 bounds the longest edge and preserves aspect ratio", %{source: source, dir: dir} do
    dest = Path.join(dir, "display.jpg")
    assert {:ok, ^dest} = Images.display(source, dest, max: 600)
    assert {:ok, %{width: 600, height: 400}} = Images.info(dest)
  end

  test "display/3 does not upscale a small source", %{dir: dir} do
    small = Path.join(dir, "small.png")
    Image.new!(120, 90, color: [0, 0, 0]) |> Image.write!(small)

    dest = Path.join(dir, "small_display.jpg")
    assert {:ok, ^dest} = Images.display(small, dest, max: 1600)
    assert {:ok, %{width: 120, height: 90}} = Images.info(dest)
  end
end
