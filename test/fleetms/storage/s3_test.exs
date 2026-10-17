defmodule Fleetms.Storage.S3Test do
  # Not async: configures the global :ex_aws / adapter env. Covers the offline
  # surface — URL building, key safety and config. The actual S3 I/O is thin
  # ExAws wrappers behind the shared `Fleetms.Storage` behaviour.
  use ExUnit.Case, async: false

  alias Fleetms.Storage.S3

  setup do
    Application.put_env(:fleetms, S3, bucket: "fleet-test", public_base_url: nil)
    Application.put_env(:ex_aws, :access_key_id, "AKIAEXAMPLE")
    Application.put_env(:ex_aws, :secret_access_key, "examplesecret")
    Application.put_env(:ex_aws, :region, "us-east-1")

    on_exit(fn ->
      Application.delete_env(:fleetms, S3)
      Application.delete_env(:ex_aws, :access_key_id)
      Application.delete_env(:ex_aws, :secret_access_key)
      Application.delete_env(:ex_aws, :region)
    end)

    :ok
  end

  describe "url/2" do
    test "returns a presigned URL by default" do
      url = S3.url("vehicles/abc/photos/og.jpg", [])

      assert url =~ "fleet-test"
      assert url =~ "vehicles/abc/photos/og.jpg"
      assert url =~ "X-Amz-Signature"
      assert url =~ "X-Amz-Expires"
    end

    test "uses the public base URL (encoded) when configured" do
      Application.put_env(:fleetms, S3,
        bucket: "fleet-test",
        public_base_url: "https://cdn.example.com"
      )

      assert S3.url("vehicles/a b/og.jpg", []) == "https://cdn.example.com/vehicles/a%20b/og.jpg"
    end
  end

  test "rejects keys that escape the storage root" do
    assert_raise ArgumentError, fn -> S3.url("a/../b", []) end
    assert_raise ArgumentError, fn -> S3.get("/etc/passwd") end
  end

  test "raises a helpful error when no bucket is configured" do
    Application.put_env(:fleetms, S3, [])
    assert_raise ArgumentError, ~r/requires a :bucket/, fn -> S3.url("x.jpg", []) end
  end
end
