defmodule Mix.Tasks.Fleetms.Bruno do
  @shortdoc "Generate a Bruno API collection from the JSON:API OpenAPI spec"

  @moduledoc """
  Generates a [Bruno](https://www.usebruno.com) collection for the public JSON:API,
  derived from the OpenAPI spec (`FleetmsWeb.ApiSpec`), into `bruno/`.

      mix fleetms.bruno

  Open the `bruno/` folder in Bruno. Pick the **Local** environment, run **Auth →
  Sign in** (set `email`/`password` first) — it captures the `token` and your first
  org's `orgPublicId` into the environment, and every other request inherits them.
  Re-run any time the API changes to regenerate.
  """
  use Mix.Task

  @out "bruno"

  @impl Mix.Task
  def run(_args) do
    Mix.Task.run("app.start")
    spec = FleetmsWeb.ApiSpec.spec()

    File.rm_rf!(@out)
    File.mkdir_p!(Path.join(@out, "environments"))

    write(Path.join(@out, "bruno.json"), bruno_json())
    write(Path.join(@out, "collection.bru"), collection_bru())
    write(Path.join(@out, "environments/Local.bru"), env_bru())
    write(Path.join(@out, "README.md"), readme())
    write_auth_folder()
    write_members_folder()

    spec.paths
    |> Enum.flat_map(fn {path, item} -> operations(path, item) end)
    |> Enum.group_by(& &1.folder)
    |> Enum.each(&write_folder/1)

    count =
      @out |> Path.join("**/*.bru") |> Path.wildcard() |> length()

    Mix.shell().info("Wrote Bruno collection (#{count} .bru files) to #{@out}/")
  end

  # --- operations from the spec -------------------------------------------------

  defp operations(path, %OpenApiSpex.PathItem{} = item) do
    for method <- [:get, :post, :patch, :put, :delete],
        op = Map.get(item, method),
        not is_nil(op) do
      tag = op.tags |> List.wrap() |> List.first() || "misc"

      %{
        folder: folder_name(tag),
        method: method,
        path: path,
        type: tag,
        has_body?: method in [:post, :patch, :put]
      }
    end
  end

  # A human folder name from a JSON:API type: "service-reminder" -> "Service reminders".
  defp folder_name(tag) do
    tag |> String.replace("-", " ") |> String.capitalize() |> pluralize()
  end

  defp pluralize(word) do
    cond do
      String.ends_with?(word, "s") -> word
      String.ends_with?(word, "y") -> String.slice(word, 0..-2//1) <> "ies"
      true -> word <> "s"
    end
  end

  # --- writing folders/requests -------------------------------------------------

  defp write_folder({folder, ops}) do
    dir = Path.join(@out, folder)
    File.mkdir_p!(dir)
    # Stable order: collection routes first, then item routes, custom actions last.
    ops
    |> Enum.sort_by(&{param_route?(&1.path), custom_action?(&1.path), method_rank(&1.method)})
    |> Enum.with_index(1)
    |> Enum.each(fn {op, seq} ->
      write(Path.join(dir, "#{filename(op)}.bru"), request_bru(op, seq))
    end)
  end

  defp param_route?(path), do: String.contains?(path, "{")
  defp custom_action?(path), do: path |> String.split("/") |> List.last() |> then(&(&1 != "{id}"))
  defp method_rank(:get), do: 0
  defp method_rank(:post), do: 1
  defp method_rank(:patch), do: 2
  defp method_rank(:put), do: 2
  defp method_rank(:delete), do: 3

  defp filename(op), do: op |> request_name() |> String.replace(~r/[^A-Za-z0-9]+/, "_")

  # e.g. "List vehicles", "Get vehicle", "Create vehicle", "vehicle: mark renewed".
  defp request_name(%{method: method, path: path, type: type}) do
    label = type |> String.replace("-", " ")
    last = path |> String.split("/") |> List.last()

    cond do
      method == :get and not param_route?(path) ->
        "List #{folder_name(type) |> String.downcase()}"

      method == :get ->
        "Get #{label}"

      method == :post and not param_route?(path) ->
        "Create #{label}"

      method == :delete ->
        "Delete #{label}"

      method in [:patch, :put] and last == "{id}" ->
        "Update #{label}"

      method in [:patch, :put, :post] ->
        "#{label}: #{String.replace(last, "-", " ")}"

      true ->
        "#{method} #{label}"
    end
  end

  defp request_bru(op, seq) do
    url = "{{baseUrl}}/api/v1" <> String.replace(op.path, "{id}", ":id")
    method = to_string(op.method)

    """
    meta {
      name: #{request_name(op)}
      type: http
      seq: #{seq}
    }

    #{method} {
      url: #{url}
      body: #{if op.has_body?, do: "json", else: "none"}
      auth: inherit
    }
    """ <>
      path_params_block(op.path) <>
      body_block(op)
  end

  defp path_params_block(path) do
    if param_route?(path) do
      """

      params:path {
        id:
      }
      """
    else
      ""
    end
  end

  defp body_block(%{has_body?: false}), do: ""

  defp body_block(%{method: method, path: path, type: type}) do
    id_line = if param_route?(path), do: ~s(    "id": ":id",\n), else: ""
    _ = method

    """

    body:json {
      {
        "data": {
          "type": "#{type}",
    #{id_line}      "attributes": {}
        }
      }
    }
    """
  end

  # --- static files -------------------------------------------------------------

  defp write_auth_folder do
    dir = Path.join(@out, "Auth")
    File.mkdir_p!(dir)

    write(Path.join(dir, "Sign_in.bru"), """
    meta {
      name: Sign in
      type: http
      seq: 1
    }

    post {
      url: {{baseUrl}}/api/v1/sign-in
      body: json
      auth: none
    }

    headers {
      Content-Type: application/json
      Accept: application/json
    }

    body:json {
      {
        "email": "{{email}}",
        "password": "{{password}}"
      }
    }

    script:post-response {
      if (res.getStatus() === 200) {
        bru.setEnvVar("token", res.getBody().token);
        const orgs = res.getBody().organizations || [];
        if (orgs.length) {
          bru.setEnvVar("orgPublicId", orgs[0].public_id);
        }
      }
    }

    docs {
      Signs in with email + password. On success it stores `token` and your first
      org's `orgPublicId` into the environment, so every other request just works.
      A long-lived API key (Account Settings in the app) can be used instead by
      setting `token` directly.
    }
    """)

    write(Path.join(dir, "OpenAPI_spec.bru"), """
    meta {
      name: OpenAPI spec
      type: http
      seq: 2
    }

    get {
      url: {{baseUrl}}/api/v1/open_api
      body: none
      auth: none
    }

    docs {
      The public OpenAPI 3 spec. A Swagger UI is served at {{baseUrl}}/api/v1/docs.
    }
    """)
  end

  # Organization member management is a plain controller (FleetmsWeb.ApiMembersController),
  # not a JSON:API route, so it isn't in the OpenAPI spec — hand-write it here like Auth.
  # It uses plain JSON (not the vnd.api+json envelope), so the requests override the
  # collection's content-type; the bearer token + x-organization header are inherited.
  defp write_members_folder do
    dir = Path.join(@out, "Members")
    File.mkdir_p!(dir)

    write(Path.join(dir, "List_members.bru"), member_request("List members", :get, "/members", 1))

    write(
      Path.join(dir, "Add_member.bru"),
      member_request("Add member", :post, "/members", 2, body: ~s({\n    "email": "",\n    "role_id": null\n  }))
    )

    write(
      Path.join(dir, "Suspend_member.bru"),
      member_request("Suspend member", :post, "/members/:id/suspend", 3, path_id: true)
    )

    write(
      Path.join(dir, "Reactivate_member.bru"),
      member_request("Reactivate member", :post, "/members/:id/reactivate", 4, path_id: true)
    )

    write(
      Path.join(dir, "Remove_member.bru"),
      member_request("Remove member", :delete, "/members/:id", 5, path_id: true)
    )
  end

  defp member_request(name, method, path, seq, opts \\ []) do
    body = Keyword.get(opts, :body)
    path_id? = Keyword.get(opts, :path_id, false)

    """
    meta {
      name: #{name}
      type: http
      seq: #{seq}
    }

    #{method} {
      url: {{baseUrl}}/api/v1#{path}
      body: #{if(body, do: "json", else: "none")}
      auth: inherit
    }

    headers {
      Accept: application/json
      Content-Type: application/json
      x-organization: {{orgPublicId}}
    }
    """ <>
      if(path_id?, do: "\nparams:path {\n  id:\n}\n", else: "") <>
      if(body, do: "\nbody:json {\n  #{body}\n}\n", else: "")
  end

  defp readme do
    """
    # FleetMS API — Bruno collection

    A [Bruno](https://www.usebruno.com) collection for the FleetMS public REST API,
    generated from the OpenAPI spec with `mix fleetms.bruno`. **Do not edit by hand** —
    re-run the task whenever the API changes; it rewrites this folder.

    ## Use it

    1. Open this `bruno/` folder in Bruno.
    2. Pick the **Local** environment and set `email` + `password` (and `baseUrl` if not
       `http://localhost:4000`).
    3. Run **Auth → Sign in**. It stores your `token` and your first org's `orgPublicId`
       into the environment; every other request inherits the bearer token and the
       `x-organization` tenant header.
    4. Run anything else.

    A long-lived **API key** (Account Settings in the app) can replace the login: set the
    `token` variable directly and skip Auth → Sign in.

    ## What's in here

    - **Auth** — token sign-in + the OpenAPI spec endpoint.
    - One folder per JSON:API resource (vehicles, work orders, contacts, …) with its CRUD
      and custom-action requests. Bodies are the `application/vnd.api+json` envelope.
    - **Members** — organization member management (`/members`). This is a plain-JSON
      controller, not a JSON:API route, so it isn't in the OpenAPI spec; these requests
      are hand-maintained in the generator and use `application/json`.
    """
  end

  defp bruno_json do
    """
    {
      "version": "1",
      "name": "FleetMS API",
      "type": "collection",
      "ignore": ["node_modules", ".git"]
    }
    """
  end

  defp collection_bru do
    """
    headers {
      Accept: application/vnd.api+json
      Content-Type: application/vnd.api+json
      x-organization: {{orgPublicId}}
    }

    auth {
      mode: bearer
    }

    auth:bearer {
      token: {{token}}
    }

    docs {
      FleetMS public JSON:API. Run Auth → Sign in first (or set `token` to an API
      key). The `x-organization` header (your org's public_id) selects the tenant.
    }
    """
  end

  defp env_bru do
    """
    vars {
      baseUrl: http://localhost:4000
      email:
      password:
      token:
      orgPublicId:
    }
    """
  end

  defp write(path, contents), do: File.write!(path, contents)
end
