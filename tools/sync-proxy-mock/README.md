# Sync Proxy Mock

Local HTTP mock for the app sync endpoints. It mirrors the cloud sync contract
used by `CloudSyncApi` and accepts all pushed records without conflicts.

## Run

```powershell
cd tools\sync-proxy-mock
node server.js
```

Default port is `8788`. Override it with `PORT`.

```powershell
$env:PORT=8788
node server.js
```

## Flutter App Wiring

Run the app with network sync enabled and point it to this mock:

```powershell
flutter run `
  --dart-define=GSC_SYNC_ENABLE_NETWORK=true `
  --dart-define=GSC_SYNC_BASE_URL=http://127.0.0.1:8788
```

For Android physical devices, use the development machine LAN IP instead of
`127.0.0.1`, or use `adb reverse tcp:8788 tcp:8788`.

The helper script starts the mock server, configures `adb reverse`, builds the
debug APK with HTTP sync enabled, and installs it:

```powershell
.\tools\sync_proxy_device_smoke.ps1
```

## API

- `GET /health`
- `GET /sync/capabilities`
- `POST /sync/push`
- `POST /sync/pull`
- `POST /sync/conflicts/preview`

## Smoke Test

The repository also includes a Dart smoke test that starts an in-process HTTP
mock and exercises `CloudSyncApi` through the real `HttpCloudSyncTransport`:

```powershell
dart run tools\sync_proxy_http_smoke.dart
```
