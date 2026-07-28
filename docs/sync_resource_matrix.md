# Sync Resource Matrix

This matrix is the current client-side contract for local-first sync. It separates data owned by a learner profile from data shared across the app/account, and lists the payload fields that must stay stable when building `SyncBatchPayloadDto`.

## Scope Rules

| Resource | Local table | Scope | Record key | Merge policy | Required payload fields | Tombstone support |
| --- | --- | --- | --- | --- | --- | --- |
| `poems` | `poems` | Global-scoped catalog cache | `cloud_id` or local poem id | Server authoritative | `poemId`, `title`, `author`, `dynasty`, `grade`, `gradeLabel`, `category`, `content`, `pinyin`, `annotation`, `translation`, `appreciation`, `authorIntro`, `extensionText`, `audioUrl`, `imageUrl`, `difficulty`, `seedVersion`, `metadata` | Yes, via `deleted_at` for local catalog rows |
| `favorites` | `favorites` | Profile-scoped | `favorite:{profileId}:{poemId}` | Soft delete | `profileId`, `poemId`, `isFavorite`, `favoritedAt`, `source`, `metadata` | Yes, `deleted_at` is sent as `metadata.isDeleted/deletedAt` |
| `learning_records` | `learning_records` | Profile-scoped | `cloud_id`, local id, or `learning:{profileId}:{poemId}:{createdAt}` | Append only | `profileId`, `poemId`, `mode`, `durationMinutes`, `score`, `note`, `sessionId`, `metadata` | No |
| `study_card_progress` | `study_card_progress` | Profile-scoped | `study_card:{profileId}:{poemId}` | Server merge suggested | `profileId`, `poemId`, `memoryStatus`, `reviewCount`, `nextReviewAt`, `note`, `metadata` | No |
| `recite_records` | `recite_records` | Profile-scoped | `cloud_id`, local id, or `recite:{profileId}:{poemId}:{createdAt}` | Append only | `profileId`, `poemId`, `score`, `recognizedText`, `transcriptVersion`, `metadata` | No |
| `wrong_questions` | `wrong_questions` | Profile-scoped | `cloud_id`, local id, or `wrong:{profileId}:{poemId}:{createdAt}` | Server merge suggested | `profileId`, `poemId`, `questionType`, `prompt`, `correctAnswer`, `userAnswer`, `ruleTag`, `severity`, `reviewedAt`, `isResolved`, `metadata` | Planned by policy; local table currently has no `deleted_at` |
| `practice_reports` | `practice_reports` + `practice_report_items` | Profile-scoped | `cloud_id`, local id, or `report:{profileId}:{sessionId}` | Append only | `profileId`, `sessionId`, `mode`, `poemId`, `totalScore`, `correctCount`, `totalQuestions`, `generatedWrongCount`, `suggestions`, `completedAt`, `items`, `metadata` | No |
| `daily_poem_records` | `daily_poem_records` | Profile-scoped | `daily:{profileId}:{dateKey}` | Last write wins | `profileId`, `dateKey`, `poemId`, `isCompleted`, `completedAt`, `metadata` | No |
| `user_points` | `user_points` | Profile-scoped | `points:{profileId}` | Server merge suggested | `profileId`, `totalPoints`, `currentPoints`, `totalCheckIns`, `consecutiveDays`, `lastCheckInDate`, `metadata` | No |
| `challenge_stage_rewards` | `challenge_stage_rewards` | Profile-scoped | `reward:{profileId}:{stageId}:{stars}` | Server merge suggested | `profileId`, `stageId`, `stars`, `claimedAt`, `metadata` | No |
| `settings` | `settings` | Global-scoped app/account settings | `settings:1` | Server merge suggested | `themeMode`, `fontScale`, `speechRate`, `dailyReminderEnabled`, `notificationsEnabled`, `showPinyin`, `reminderHour`, `reminderMinute`, `activeProfileId`, `seedVersion`, `metadata` | No |
| `user_profiles` | `profile_accounts` | Profile-scoped profile resource | `profile:{profileId}` | Server merge suggested | `profileId`, `nickname`, `tagline`, `avatarSeed`, `lastActiveAt`, `metadata` | Planned by policy; local table currently has no `deleted_at` |

## Metadata Contract

Every resource payload must preserve `metadata.localId`, `metadata.cloudId`, `metadata.revisionToken`, `metadata.clientMutationId`, `metadata.lastActorDeviceId`, `metadata.createdAt`, `metadata.updatedAt`, `metadata.deletedAt`, `metadata.isDeleted`, `metadata.isEncrypted`, and `metadata.schemaVersion`.

Rows are eligible for upload when `sync_status = 'pending_push'`. Soft-deleted rows must remain pending until the server acknowledges the tombstone; currently favorites are the exercised tombstone path.

## Local Pending Conflict Rules

When `applyRemoteEnvelope()` receives a remote record for a row that is already `sync_status = 'pending_push'`, the client resolves it by the collection merge policy:

| Merge policy | Client behavior while local row is pending |
| --- | --- |
| `last_write_wins` | Compare `metadata.updatedAt` with local `updated_at`; the newer side wins. Older remote records are skipped so the local pending edit remains uploadable. |
| `soft_delete` | Compare tombstone/update time. A newer local delete is preserved; a newer remote delete/update is applied and clears pending state. |
| `server_merge_suggested` | Treat the remote row as the server-merged result and apply it, clearing local pending state for that row. |
| `server_authoritative` | Apply the remote row, clearing local pending state. |
| `append_only` | Apply the remote row only through idempotent keys such as `cloud_id`, `client_mutation_id`, or resource identity; duplicate recovery is avoided by repository upsert helpers. |

## Current Boundary

`CloudSyncApi` intentionally does not perform network I/O yet. It now exposes `CloudSyncApiConfig` and `CloudSyncTransport` so a future HTTP adapter can map:

| Operation | Reserved endpoint |
| --- | --- |
| Capabilities | `/sync/capabilities` |
| Push | `/sync/push` |
| Pull | `/sync/pull` |
| Conflict preview | `/sync/conflicts/preview` |

The default `enableNetwork = false` keeps tests and app behavior on structured placeholder responses.
