# Deploying the FleetMS demo to Fly.io

A one-time setup to get a clickable demo online. This is demo-grade (Fly's
legacy/unmanaged Postgres, scale-to-zero, no email) — not production.

## Prerequisites

- `flyctl` installed and logged in (`fly auth login`).
- This repo checked out, with `fly.toml` present.

## 1. Create the app

Pick a unique name; it becomes `https://<name>.fly.dev`.

```sh
fly apps create fleetms-demo   # or your own name
```

Then edit `fly.toml`: set `app` and `PHX_HOST` to match (`<name>` and
`<name>.fly.dev`).

## 2. Create and attach Postgres (legacy / unmanaged)

```sh
fly postgres create --name fleetms-demo-db --region jnb --vm-size shared-cpu-1x --initial-cluster-size 1 --volume-size 1
fly postgres attach fleetms-demo-db --app fleetms-demo
```

`attach` sets the `DATABASE_URL` secret on the app automatically.

**Give the DB 1 GB of RAM.** `shared-cpu-1x` defaults to **256 MB**, which
OOM-kills `postgres-flex` under any real connection load — the machine shows
`role: error` with failing health checks, and the app can't hold connections
(`Postgrex … handshaking for longer than 15000ms`, `tcp recv (idle): closed`).
Bump it before deploying:

```sh
fly machine list --app fleetms-demo-db          # get the DB machine id
fly machine update <db-machine-id> --vm-memory 1024 --app fleetms-demo-db --yes
```

The machine should then reach `role: primary` with all checks passing
(`fly status --app fleetms-demo-db`).

## 3. Set the app secrets

```sh
fly secrets set \
  SECRET_KEY_BASE="$(mix phx.gen.secret)" \
  TOKEN_SIGNING_SECRET="$(mix phx.gen.secret)" \
  ECTO_IPV6=true \
  --app fleetms-demo
```

`ECTO_IPV6=true` is required — Fly's private network (and therefore its Postgres)
is IPv6-only, and `runtime.exs` only enables the IPv6 database socket when it's set.

## 4. Create the uploads volume

Uploaded photos, signatures and documents are written to local disk, which is
ephemeral on Fly. `fly.toml` mounts a volume at `/data` (and `config/prod.exs`
points local storage + the `/uploads` route at `/data/uploads`) so they survive
redeploys. Create the volume before the first deploy, in the same region as the app:

```sh
fly volumes create fleetms_data --region jnb --size 1 --app fleetms-demo
```

The name must match `[[mounts]].source` in `fly.toml` (`fleetms_data`). One
volume attaches to one machine — fine for this single-machine demo.

**Alternative — object storage instead of the volume.** Any S3-compatible bucket
(Cloudflare R2, Backblaze B2, …) also works and needs no volume; the app switches
to S3 automatically once `S3_BUCKET` is set:

```sh
fly secrets set \
  S3_BUCKET="fleetms-demo" \
  AWS_ACCESS_KEY_ID="..." \
  AWS_SECRET_ACCESS_KEY="..." \
  AWS_REGION="auto" \
  S3_HOST="<accountid>.r2.cloudflarestorage.com" \
  --app fleetms-demo
```

## 5. Deploy

```sh
fly deploy --app fleetms-demo
```

The build installs Node + pnpm and runs `mix assets.deploy` (Tailwind + the
Svelte islands), then assembles the release. Before the new release goes live the
`release_command` (`/app/bin/migrate`) runs the **public** migrations. The
per-tenant (schema-per-org) migrations run **off the deploy critical path**: the
app enqueues one background job per organization on boot, so a large fleet of
tenants never slows the deploy. (See "Tenant migrations" under Notes.)

## 6. Seed the demo data

On a fresh database, load the two demo organizations and their data:

```sh
fly ssh console --app fleetms-demo --command "/app/bin/seed"
```

The seed is a no-op if the database already has organizations, so it's safe to
re-run.

## 7. Open it

```sh
fly open --app fleetms-demo
```

Sign in with the seeded accounts:

- **Corporate:** `manager@kabwehaulage.example` / `password1234`
- **Individual:** `chanda@example.com` / `password1234`
- **Members (username sign-in):** `phiri`, `tembo`, `sakala` / `password1234`

## Notes

- **Email** is off until you pick a provider — invites, password resets and the
  daily digests won't send, and the no-op logger adapter just logs them. The seeded
  logins above are pre-confirmed, so sign-in still works. To turn email on, set
  `MAILER_ADAPTER` plus the matching secrets, and `EMAIL_FROM`:
  - `MAILER_ADAPTER=smtp` + `SMTP_RELAY`, `SMTP_USERNAME`, `SMTP_PASSWORD`
    (`SMTP_PORT` default 587, `SMTP_TLS` default `if_available`, `SMTP_SSL` `true`/`false`)
  - `MAILER_ADAPTER=mailgun` + `MAILGUN_API_KEY`, `MAILGUN_DOMAIN`
  - `MAILER_ADAPTER=sendgrid` + `SENDGRID_API_KEY`
  - `MAILER_ADAPTER=postmark` + `POSTMARK_API_KEY`

  e.g. `fly secrets set MAILER_ADAPTER=smtp SMTP_RELAY=... SMTP_USERNAME=... SMTP_PASSWORD=... EMAIL_FROM=no-reply@yourco.com`.
  The wiring lives in `config/runtime.exs`; all transactional emails are sent as
  multipart HTML + plain text for deliverability.
- **Payments (go-live).** The DPO and Lenco integrations are built and read their
  credentials from the environment (live endpoints are the defaults; the sandbox
  DPO token is only used in dev). To accept real payments:
  - **DPO:** `fly secrets set DPO_COMPANY_TOKEN=... DPO_SERVICE_TYPE=...`. In the DPO
    dashboard set the customer **redirect/return URL** to
    `https://<your-host>/pay/dpo/return` (the app verifies the token before trusting
    the return).
  - **Lenco:** `fly secrets set LENCO_API_TOKEN=...`. In the Lenco dashboard register
    the **webhook URL** `https://<your-host>/billing/webhooks/lenco` for
    `virtual-account.transaction` events — it's verified with the signed
    `X-Lenco-Signature` header, so no separate webhook secret is needed.

  Until a token is set, that provider is simply unavailable; a subscription can also
  be marked paid manually (the `:manual` provider). Plans/prices live in the billing
  data; the daily `SweepSubscriptions` job expires past-due subscriptions after the
  `grace_days` window (default 7).
- **Redeploys** (`fly deploy`) re-run `/app/bin/migrate` (public schema) before
  cutover, then migrate tenant schemas in the background on boot — no manual step
  for schema changes.
- **Tenant migrations.** These run as background Oban jobs (queue
  `tenant_migrations`), one per organization, enqueued on boot
  (`Fleetms.TenantMigrations`). Two consequences: (1) a tenant schema may be one
  migration behind for a short window after a deploy, so **tenant-schema changes
  must stay backward compatible** with the release until the jobs run
  (expand/contract); (2) to apply them synchronously by hand — e.g. before a
  breaking change — run `fly ssh console --app fleetms-demo --command
  "/app/bin/migrate_tenants"`.
- **Memory.** The BEAM (Ash + Oban + PromEx + Phoenix) OOM-kills on boot at
  512 MB; `fly.toml` sets the app VM to 1 GB, which is comfortable. The **Postgres**
  machine also needs 1 GB — its `shared-cpu-1x` default of 256 MB OOM-kills
  `postgres-flex` (see step 2).
- **Metrics endpoint (`/metrics`).** PromEx serves Prometheus metrics at `/metrics`
  for scraping. These contain operational data (request rates, route names, VM and
  job stats), so the endpoint should not be publicly reachable. Lock it down one of
  two ways:
  1. **Firewall/proxy** — the usual setup: only let your Prometheus scraper reach
     `/metrics` (private network, or block the path at the reverse proxy). Nothing to
     configure in the app.
  2. **Scrape token** — set `PROMETHEUS_METRICS_TOKEN` (e.g.
     `fly secrets set PROMETHEUS_METRICS_TOKEN=$(openssl rand -hex 32)`) and the app
     requires `Authorization: Bearer <token>` on `/metrics`; configure the same
     bearer token on the Prometheus scrape job. Left unset, `/metrics` stays open
     (handy in local dev), so rely on option 1 if you don't set a token.
- **Health check:** Fly polls `GET /health` (a dependency-free 200).
- **Logs / console:** `fly logs` and `fly ssh console`.
- **If the `release_command` migrate fails with `:nxdomain`** resolving the DB
  host: Fly's release machines sometimes can't resolve org-internal DNS
  (`.internal` / `.flycast`), even though normal app machines can. Two ways round it:
  1. Point `DATABASE_URL` at the DB's **flycast IP** instead of its hostname —
     find it with `fly ips list --app <db-app>` (the `private ingress` row) and use
     `postgres://<user>:<pw>@[<that-ipv6>]:5432/<db>?sslmode=disable`. The
     release_command then needs no DNS.
  2. Or remove `[deploy] release_command` from `fly.toml`, deploy, and run
     `/app/bin/migrate` (then `/app/bin/seed`) via `fly ssh console` on the running
     machine, which resolves DNS normally.
