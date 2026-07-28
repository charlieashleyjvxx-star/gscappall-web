# Sync Proxy Protocol

This document defines the HTTP contract for replacing `sync-proxy-mock` with a
real backend. The Flutter client talks only to this proxy, not directly to a
vendor or database service.

## Transport

- Base URL: configured by `GSC_SYNC_BASE_URL`.
- App build flags:
  - `GSC_SYNC_ENABLE_NETWORK=true`
  - `GSC_SYNC_BASE_URL=<proxy-base-url>`
  - `GSC_SYNC_APP_VERSION=<app-version>`
- The app should obtain `accessToken`, `refreshToken`, `accountId`, and
  `profileIds` through the login/refresh flow, then persist them locally.
- Content type: `application/json; charset=utf-8`.
- Time format: ISO-8601 UTC strings.
- Authentication: `Authorization: Bearer <accessToken>`.
- Account isolation: `X-GSC-Account-Id`; if omitted in local development, the
  proxy may derive an account id from the bearer token.
- Profile authorization: `X-GSC-Profile-Ids`, a comma-separated allow-list of
  profile ids that the current account/session can access.
- Device headers:
  - `X-GSC-Device-Id`: stable client device id generated once by the app and
    persisted locally.
  - `X-GSC-App-Version`: app version.
  - `X-GSC-Schema-Version`: local sync schema version.

## Identity Boundary

The current proxy contains a local password account service for development and
staging. Production identity should replace only the account service boundary,
not the sync protocol:

- Keep issuing proxy-local `accessToken` and `refreshToken` values so Flutter
  transport headers stay unchanged.
- Validate user credentials, refresh-token ownership, disabled accounts, and
  profile grants against the production identity provider or account database.
- Map the production user id to `accountId`; never trust `X-GSC-Account-Id`
  without a matching bearer token session.
- Read profile authorization from server-side grants and return it in login and
  refresh responses. The `X-GSC-Profile-Ids` header is a requested scope, not a
  source of truth.
- Rotate refresh tokens on login/refresh and revoke access tokens on logout.

## Checkpoint And Cursor

The server owns cursor generation.

```json
{
  "globalCursor": "server-global-cursor",
  "collectionCursors": {
    "favorites": "favorites-cursor",
    "learning_records": "learning-records-cursor"
  },
  "lastSuccessfulSyncAt": "2026-05-11T10:00:00.000Z",
  "schemaVersion": 10
}
```

Client rules:

- Send the last stored checkpoint with every push/pull.
- Persist the returned checkpoint after a successful sync stage.
- Treat unknown collection cursors as opaque strings.
- Do not synthesize server cursors locally in production.

## Endpoints

### `GET /sync/capabilities`

Returns merge behavior and server limits.

```json
{
  "supportsPoemCatalog": true,
  "supportsSoftDelete": true,
  "supportsFieldMerge": true,
  "maxBatchSize": 500,
  "maxPullRecords": 500,
  "supportedPolicies": {
    "favorites": "last_write_wins",
    "learning_records": "append_only",
    "wrong_questions": "last_write_wins",
    "user_points": "server_merge_suggested"
  },
  "notes": []
}
```

### `POST /auth/refresh`

Refreshes local sync credentials and grants profile access for this account.

```json
{
  "accountId": "dev-account",
  "refreshToken": "server-issued-refresh-token"
}
```

Response:

```json
{
  "accountId": "dev-account",
  "accessToken": "server-issued-token",
  "refreshToken": "rotated-refresh-token",
  "expiresAt": "2026-05-12T10:00:00.000Z",
  "profileIds": [1, 2]
}
```

### `POST /auth/register`

Development/staging endpoint for creating a local account. Production may
replace this route with the real identity provider, but should preserve the
response shape.

```json
{
  "accountId": "dev-account",
  "password": "local-dev-password",
  "profileIds": [1, 2]
}
```

### `POST /auth/login`

Development/staging endpoint for password login. Production should validate
against the real account service and return the same session envelope.

```json
{
  "accountId": "dev-account",
  "password": "local-dev-password"
}
```

### `POST /auth/logout`

Revokes the current access token. `revokeAll=true` revokes all active access
tokens for the account.

```json
{
  "revokeAll": false
}
```

### `POST /sync/push`

Request body is `SyncUpstreamPayloadDto`.

Response:

```json
{
  "requestId": "client-request-id",
  "checkpoint": {},
  "acceptedCounts": {
    "favorites": 3,
    "wrong_questions": 1
  },
  "conflicts": [],
  "serverTime": "2026-05-11T10:00:00.000Z",
  "notes": ["accepted all records"]
}
```

`acceptedCounts` is per resource and controls which local `pending_push` rows
can be marked as `local`. If a resource is missing or count is lower than sent,
the remaining local rows stay pending.

### `POST /sync/pull`

Request body is `SyncPullRequestDto`.

Response:

```json
{
  "checkpoint": {},
  "batch": {
    "favorites": [],
    "wrongQuestions": [],
    "settings": []
  },
  "receivedCounts": {
    "favorites": 1
  },
  "conflicts": [],
  "serverTime": "2026-05-11T10:00:00.000Z",
  "notes": []
}
```

`batch` uses the app DTO keys. Every profile-scoped record must carry
`profileId`.

Large pull envelopes should be paged or sharded by resource:

- Server returns at most `maxPullRecords` records per response.
- Collection cursors remain per-resource opaque revision strings.
- If any collection has more records, the response should include
  `hasMore: true` and the client immediately repeats pull with the returned
  checkpoint.
- The client must apply each page idempotently through `applyRemoteEnvelope()`
  before requesting the next page.
- A pull page must never mix data outside the authorized profile scope.

### `POST /sync/conflicts/preview`

Returns conflict suggestions without mutating server state.

```json
{
  "conflicts": [
    {
      "resource": "favorites",
      "recordKey": "favorite:1:10",
      "mergePolicy": "soft_delete",
      "recommendedWinner": "remote",
      "localPayload": {},
      "remotePayload": {},
      "mergedPayload": null,
      "fieldsInConflict": ["isDeleted"],
      "reason": "remote tombstone is newer"
    }
  ]
}
```

## Conflict Rules

- `last_write_wins`: compare `updatedAt`; newer payload wins.
- `soft_delete`: tombstone wins when delete timestamp is newer or equal.
- `append_only`: server accepts unique record keys and ignores duplicates.
- `server_merge_suggested`: server returns `mergedPayload`; client keeps local
  pending rows until ACK confirms acceptance.
- `server_authoritative`: client treats remote payload as source of truth.

## Error Shape

All non-2xx responses should return:

```json
{
  "error": {
    "code": "UNAUTHORIZED",
    "message": "Access token expired.",
    "retryable": false,
    "details": {}
  }
}
```

Recommended codes: `UNAUTHORIZED`, `ACCOUNT_FORBIDDEN`, `PROFILE_FORBIDDEN`,
`DEVICE_REVOKED`, `SCHEMA_TOO_OLD`, `PAYLOAD_TOO_LARGE`, `BATCH_TOO_LARGE`,
`CONFLICT_REQUIRES_REVIEW`, `RATE_LIMITED`,
`INTERNAL_ERROR`.
