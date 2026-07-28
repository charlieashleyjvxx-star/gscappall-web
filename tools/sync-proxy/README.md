# Sync Proxy

Formal backend skeleton for GSCAPPALL cloud sync. It follows
`docs/sync_proxy_protocol.md` and supports both SQLite local persistence and a
Postgres adapter through the shared store interface.

## Run

```powershell
cd tools\sync-proxy
node server.js
```

Defaults:

- `PORT=8790`
- `SYNC_PROXY_REQUIRE_AUTH=true`
- `SYNC_PROXY_ACCESS_TOKEN_TTL_HOURS=24`
- `SYNC_PROXY_DB=tools/sync-proxy/sync-proxy.sqlite`
- `SYNC_PROXY_STORE=sqlite`
- `SYNC_PROXY_STORE=postgres` enables the Postgres adapter.
- `SYNC_PROXY_POSTGRES_URL` is the Postgres connection string.
- `SYNC_PROXY_MAX_BATCH_SIZE=500` rejects oversized push/preview batches.

For local unauthenticated experiments:

```powershell
$env:SYNC_PROXY_REQUIRE_AUTH="false"
node server.js
```

Flutter debug build against this proxy:

```powershell
flutter run `
  --dart-define=GSC_SYNC_ENABLE_NETWORK=true `
  --dart-define=GSC_SYNC_BASE_URL=http://127.0.0.1:8790 `
  --dart-define=GSC_SYNC_APP_VERSION=0.1.0-dev
```

For Android physical devices, use `adb reverse tcp:8790 tcp:8790` or replace
`127.0.0.1` with the development machine LAN IP.

Postgres smoke:

```powershell
powershell -ExecutionPolicy Bypass -File tools\sync_proxy_postgres_smoke.ps1
```

Management smoke:

```powershell
powershell -ExecutionPolicy Bypass -File tools\sync_proxy_management_smoke.ps1
```

Productionization plan:

```text
docs/sync_productionization_plan.md
```

The smoke script creates a disposable `gscappall_sync_smoke` database, runs
`npm install`, starts the proxy with `SYNC_PROXY_STORE=postgres`, registers a
local account, refreshes the access token, then verifies push/pull, oversized
batch rejection, account isolation, profile authorization, conflict responses,
and full-resource multi-profile replay coverage.

## Implemented

- Access-token authentication middleware backed by `sync_access_tokens`.
- Local account registration and password login through `POST /auth/register`
  and `POST /auth/login`.
- Token refresh endpoint: `POST /auth/refresh` validates a refresh token,
  returns `accessToken`, `expiresAt`, `accountId`, and server-side profile
  grants.
- Logout endpoint: `POST /auth/logout` revokes the current access token.
- Refresh token rotation on login/refresh, expired access-token cleanup, and
  basic per-IP/token rate limiting.
- Account isolation via the account attached to the access token; mismatched
  `X-GSC-Account-Id` headers are rejected.
- Profile authorization via `X-GSC-Profile-Ids`; profile-scoped records outside
  the server-side grant table are rejected with `PROFILE_FORBIDDEN`.
- Device registration via `POST /devices/register` and implicit registration on
  sync endpoints.
- SQLite-backed device, record, revision, and cursor persistence.
- Postgres-backed implementation of the same store interface.
- Store adapter boundary: `adapters/sqlite_adapter.js` and
  `adapters/postgres_adapter.js` implement the same runtime store interface.
- `POST /sync/push` ACK with per-resource `acceptedCounts`.
- `POST /sync/pull` envelope generated from records newer than the supplied
  collection cursor.
- Conflict detection for `last_write_wins`, `soft_delete`, and
  `server_merge_suggested`.
- Batch-size enforcement through `SYNC_PROXY_MAX_BATCH_SIZE`.
- Request log management through `GET /debug/request-logs` with pagination and
  `requestId`/status/error filters, plus `POST /debug/request-logs/prune`.
- Standard error shape from the protocol document.

## Remaining Before Production

- Replace the local password account service with the production identity
- provider when it is available. Keep the existing session response shape and
  proxy-local access-token validation.
- Move Postgres schema changes from startup DDL to versioned migrations before
  production deployment.
- Add pull pagination with `maxPullRecords`/`hasMore` before large multi-device
  restore scenarios.
- Export structured metrics to the production observability stack.
