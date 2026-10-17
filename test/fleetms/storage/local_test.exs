defmodule Fleetms.Storage.LocalTest do
  # Not async: each test rewrites the adapter's base_dir in the global app env.
  use ExUnit.Case, async: false

  alias Fleetms.Storage

  # Each test gets an isolated base dir under its own tmp root.
  setup do
    base_dir =
      Path.join(System.tmp_dir!(), "fleetms_storage_#{System.unique_integer([:positive])}")

    Application.put_env(:fleetms, Storage.Local, base_dir: base_dir, base_url: "/uploads")
    on_exit(fn -> File.rm_rf!(base_dir) end)
    %{base_dir: base_dir}
  end

  defp source_file(contents) do
    path = Path.join(System.tmp_dir!(), "src_#{System.unique_integer([:positive])}.txt")
    File.write!(path, contents)
    on_exit(fn -> File.rm_rf(path) end)
    path
  end

  test "put/get round-trips a file under a nested key", %{base_dir: base_dir} do
    src = source_file("hello fleet")
    key = "vehicles/abc/documents/manual.txt"

    assert {:ok, ^key} = Storage.put(key, src)
    assert File.exists?(Path.join(base_dir, key))
    assert {:ok, "hello fleet"} = Storage.get(key)
  end

  test "put_binary stores in-memory contents" do
    key = "vehicles/abc/photos/th_front.jpg"
    assert {:ok, ^key} = Storage.put_binary(key, "JPEGDATA")
    assert {:ok, "JPEGDATA"} = Storage.get(key)
  end

  test "exists?/delete reflect object presence" do
    key = "vehicles/abc/photos/og_front.jpg"
    refute Storage.exists?(key)

    Storage.put_binary(key, "x")
    assert Storage.exists?(key)

    assert :ok = Storage.delete(key)
    refute Storage.exists?(key)
  end

  test "delete is idempotent for a missing key" do
    assert :ok = Storage.delete("vehicles/missing/nope.jpg")
  end

  test "url joins the base url with encoded key segments" do
    assert Storage.url("vehicles/a b/og file.jpg") == "/uploads/vehicles/a%20b/og%20file.jpg"
  end

  test "rejects keys that try to escape the storage root" do
    assert_raise ArgumentError, fn -> Storage.put_binary("../../etc/passwd", "x") end
    assert_raise ArgumentError, fn -> Storage.get("/etc/passwd") end
    assert_raise ArgumentError, fn -> Storage.url("a/../../b", []) end
  end
end
