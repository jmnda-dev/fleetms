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
