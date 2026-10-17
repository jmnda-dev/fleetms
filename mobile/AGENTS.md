# FleetMS Mobile — agent & contributor guide

This is the **consistency contract** for the FleetMS mobile app. Read it fully before
adding code. It was scaffolded to be picked up and extended (incl. by AI tools) without
drifting. Match these patterns; don't introduce parallel ways of doing the same thing.

> For the whole‑project picture (backend architecture, the API you consume,
> conventions, deployment, current state), read **`../docs/PROJECT_CONTEXT.md`** first.
> The live API's Swagger UI is at `/api/v1/docs` and a Bruno collection is in `../bruno/`.

## What this app is
An **offline-first Flutter** app for fleet field work (drivers/technicians logging fuel,
odometer, issues and inspections — often in yards/garages/dead zones). It is a **client of
the FleetMS JSON:API** (Elixir/Phoenix/Ash backend in the parent repo). No business logic
lives here that the API already owns — the app captures input, caches, and syncs.

## Stack decisions (do NOT swap without a written reason here)
- **Flutter** (stable channel), Dart 3.
- **State management: Riverpod** (`flutter_riverpod`), **manual providers only** — no
  `@riverpod` codegen, so the project stays build_runner-free except where noted.
- **Navigation: `go_router`** (single `routing/router.dart`, auth redirect).
- **HTTP: `dio`** with interceptors — one `ApiClient`; never call `dio` directly from UI.
- **Secure storage: `flutter_secure_storage`** for the token + selected org.
- **Offline cache/outbox: `drift` (SQLite)** — **wired** (vehicles cache, a write outbox, and
  a connectivity-driven sync; see Offline).
- **Models: plain Dart classes** with a `fromJsonApi` factory. No json_serializable/freezed
  for now (keeps it codegen-free and legible). If a model gets large, revisit here first.

## The API contract (what the backend gives you)
- Base URL comes from `core/config.dart` (`AppConfig.baseUrl`, default `http://10.0.2.2:4000`
  for the Android emulator → host `localhost`). Everything is under **`/api/v1`**.
- **Media type is JSON:API**: send/accept `application/vnd.api+json`.
- **Auth**: `Authorization: Bearer <token>`. Get a token from
  `POST /api/v1/sign-in {email,password}` → `{token, token_type, user_id, organizations:[{id,public_id,name,owner}]}`.
  A long-lived API key works as the bearer token too.
- **Tenant**: every data request must send **`x-organization: <org public_id>`** (from the
  chosen organization). The `ApiClient` injects both headers automatically once a session +
  org are set — features never set them by hand.
- **Payload shape**: `{ "data": { "type": "...", "id": "...", "attributes": {...} } }` for
  writes; reads return `{ "data": [...] }` or `{ "data": {...} }`. Use `core/json_api.dart`
  helpers (`JsonApi.one/many/attributes`) — never reach into the raw map in a screen.
- **Decimals arrive as strings.** The API serializes Ash `decimal` fields (mileage, money,
  quantities…) as JSON strings to keep precision, so `attrs['x'] as num?` throws. Read
  numeric attributes through `JsonApi.asNum(attrs['x'])` in `fromJsonApi`.
- **Docs**: OpenAPI at `/api/v1/open_api`, Swagger UI at `/api/v1/docs`, and a Bruno
  collection in the parent repo's `bruno/`. Use them to see every resource/route.

## Folder layout (feature-first)
```
lib/
  main.dart                 # entry: ProviderScope + FleetmsApp
  app.dart                  # MaterialApp.router + theme
  core/                     # cross-cutting: config, api client, json:api, storage
  routing/router.dart       # go_router + auth redirect
  features/<feature>/
    models/                 # plain Dart models w/ fromJsonApi
    <feature>_repository.dart   # talks to ApiClient, returns models
    <feature>_controller.dart   # Riverpod Notifier/AsyncNotifier — screens watch this
    screens/                    # widgets only; no HTTP here
```
`auth` and `vehicles` are the two **reference features** — copy their shape for every new
resource. `vehicles` is the canonical read/list example; `auth` is the session example.

## How to add a resource screen (the recipe)
1. Add a model in `features/<x>/models/<x>.dart` with `factory X.fromJsonApi(Map json)`.
2. Add `features/<x>/<x>_repository.dart` with methods calling `ref.read(apiClientProvider)`
   (e.g. `client.getMany('/x')`, `client.getOne('/x/$id')`, `client.post('/x', attributes)`).
3. Add `features/<x>/<x>_controller.dart` — an `AsyncNotifier`/`Notifier` exposing state.
4. Add screen(s) under `features/<x>/screens/` that `ref.watch` the controller. No `dio`,
   no header logic, no JSON:API parsing in the screen.
5. Register any route in `routing/router.dart`.
Resource types & routes are exactly the JSON:API ones — see `bruno/` or `/api/v1/open_api`.

## Offline strategy (the whole point)
Reads render from a **local SQLite cache** (drift) where wired; writes fall back to a **local
outbox** and sync when connectivity returns. The current state:
- **Cache:** `vehicles` caches to drift and falls back to it offline (`VehiclesRepository`).
  Extend the same pattern (cache-first read, refresh from API) to other resources as needed.
- **Outbox:** `issues`, `fuel` and `inspections` create falls back to the `outbox_entries`
  table (endpoint + method + JSON:API body) when the POST fails.
- **Sync:** `OutboxSyncService` flushes the outbox on **auth** (triggered from `app.dart`) and
  on **connectivity regain** (`connectivity_plus`). It only flushes with a live session
  (`ApiClient.hasSession`) and only discards a queued write on genuine client-data errors
  (400/409/422) — auth/rate-limit/5xx stay queued to retry. **Do not** read the sync provider
  lazily and expect it to run; it must be constructed (it is, via the `app.dart` listener).
- The API's creates are safe to retry (idempotent enough for this), so re-flushing is fine.
Keep cache/outbox logic **inside repositories** so controllers/screens never know if data came
from cache or network. Server-side-id reconciliation for temp rows is still a TODO.

## Conventions
- Money: the API sends amounts with a currency; render as given, don't assume a currency.
- Distances/volumes: the API stores canonical (km/litres); show the org's unit — the org
  settings are available via the API if needed. Don't hardcode miles/km.
- Errors: repositories throw `ApiException` (see `core/api_client.dart`); controllers turn
  them into `AsyncError`; screens show them. Don't swallow errors silently.
- Never commit secrets. `AppConfig.baseUrl` is the only environment knob for now.
- Run `dart format .` and `flutter analyze` before committing; keep `flutter analyze` clean.

## First-run setup (do this once in Flutter tooling — it's not in this scaffold)
This scaffold contains `lib/`, `pubspec.yaml`, configs and `test/` but **no native
platform shells** (they're git-ignored — regenerate per environment). In `mobile/`:
```
flutter create --org com.fleetms --platforms=android,ios,web .   # generates android/ ios/ web/
flutter pub get
flutter run
```
`flutter create` fills the platform folders without touching `lib/` (it also drops a
stock `test/widget_test.dart` referring to a non-existent `MyApp` — delete it; the real
tests live beside it). Then `flutter run`.

Verified toolchain (2026-09-12): Flutter 3.47.4 stable / Dart 3.13.3. `flutter analyze`
and `flutter test` are clean, and `flutter build web` compiles. `flutter doctor` is green
for the Android and Linux toolchains.
