# Stage Scope Navigation

`StageScopeRouteArgs` is the shared route argument for challenge-stage context. Any page opened from a challenge stage should pass the same `stageId`, so reports, wrong questions, learning history, growth reports, and the challenge map stay in one review chain.

## Named Routes

| Route | Purpose | Arguments |
| --- | --- | --- |
| `/challenge-map` | Challenge map | `stageId` highlights/keeps the scoped stage. |
| `/practice-reports` | Report history | `stageId` applies the stage filter. |
| `/practice-report-detail` | Single report detail | `reportId` opens one report. `stageId` may be included for context. |
| `/wrong-book` | Wrong book | `stageId` applies the stage filter. |
| `/wrong-question-detail` | Single wrong-question detail | `wrongQuestionId` opens one wrong question. `stageId` may be included for context. |
| `/learning-history` | Learning history | `stageId` applies the stage filter. |
| `/learning-record-detail` | Single learning record detail | `learningRecordId` opens one record. `stageId` may be included for context. |
| `/growth-report` | Growth report detail | `period=weekly/monthly` selects the report period. `stageId` shows the scoped-stage growth card and can jump back to map. |
| `/daily-poem` | Daily poem | No stage scope required. |
| `/sync-logs` | Sync log list | No stage scope required. |
| `/sync-log-detail` | Sync log detail | Accepts a `SyncRunLogEntry`; parses stage/report/wrong-question ids from notes/error and exposes shortcuts. |

## Notification Payload Protocol

Notification payloads are parsed by `routeFromNotificationPayload`.

| Payload | Route result |
| --- | --- |
| `daily_poem` or `daily_poem_*` | `/daily-poem` |
| `stage:<stageId>` | `/challenge-map` with `StageScopeRouteArgs(stageId)` |
| `route:/practice-reports?stageId=<stageId>` | Report history with stage filter |
| `route:/wrong-book?stageId=<stageId>` | Wrong book with stage filter |
| `route:/learning-history?stageId=<stageId>` | Learning history with stage filter |
| `route:/growth-report?stageId=<stageId>` | Growth report with stage context |
| `route:/growth-report?period=monthly&stageId=<stageId>` | Monthly growth report with stage context |
| `route:/practice-report-detail?reportId=<id>&stageId=<stageId>` | Direct report detail |
| `route:/wrong-question-detail?wrongQuestionId=<id>&stageId=<stageId>` | Direct wrong-question detail |
| `route:/learning-record-detail?learningRecordId=<id>&stageId=<stageId>` | Direct learning record detail |

When adding a new notification type, prefer the `route:` form unless the payload is a legacy reminder. Add or update `test/notification_route_payload_test.dart` so the route name and argument contract stay stable.

## Android Regression Entry

Use the route-chain smoke entry before or during Android regression:

```powershell
pwsh -File tools/android_reading_regression.ps1 -Serial <device-serial> -RouteChainSmoke -SkipSmokeFlows
```

This runs the notification payload, sync-log shortcut, and stage scoped navigation chain tests without doing the longer reading/speech flow.
