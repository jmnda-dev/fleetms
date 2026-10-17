# FleetMS Mobile

Offline-first Flutter app for FleetMS field work, a client of the FleetMS JSON:API.

> **Read [`AGENTS.md`](AGENTS.md) first** — it's the architecture + conventions contract
> everyone (including AI tools) must follow. This README is just how to run it.

## Status
Scaffold: architecture, API client, auth (login + org picker), and one reference feature
(vehicles list) are in place. It has **not been compiled yet** (built without the Flutter
SDK on hand) and has **no native platform folders yet** — first run below fills those in.
Offline caching (drift) is chosen and documented but not yet wired.

## First run
Requires the Flutter SDK (stable). In this `mobile/` directory:

```bash
# 1. Generate the native platform shells (android/ ios/ web/). Doesn't touch lib/.
flutter create --org com.fleetms --platforms=android,ios,web .

# 2. Fetch packages.
flutter pub get

# 3. Point at your API (defaults to the Android emulator's host alias for
#    localhost:4000). Use --dart-define to override, e.g. a device on your LAN:
flutter run --dart-define=FLEETMS_BASE_URL=http://192.168.1.20:4000
```

Sign in with a FleetMS user's email + password. If the user belongs to several orgs you'll
pick one; that selection becomes the `x-organization` tenant for the session.

## Backend
The Phoenix/Ash API lives in the parent repo. Run it (`mix phx.server`), and browse the API
at `/api/v1/docs` (Swagger) or via the Bruno collection in the parent repo's `bruno/`.

## Layout
See `AGENTS.md`. In short: `core/` (config, api client, json:api, storage), `routing/`,
and `features/<x>/` (models, repository, controller, screens). `features/auth` and
`features/vehicles` are the patterns to copy.
