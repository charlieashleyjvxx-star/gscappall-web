param(
  [int]$Port = 8788,
  [string]$BaseUrl = "http://127.0.0.1:8788",
  [switch]$SkipBuild
)

$ErrorActionPreference = "Stop"

function Assert-Command($Name) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "$Name is not available in PATH."
  }
}

Assert-Command adb
Assert-Command flutter
Assert-Command node

$devices = adb devices | Select-String "`tdevice$"
$unauthorized = adb devices | Select-String "`tunauthorized$"
if ($unauthorized) {
  throw "ADB device is unauthorized. Confirm the USB debugging prompt on the phone, then rerun this script."
}
if (-not $devices) {
  throw "No authorized Android device found."
}

$previousPort = $env:PORT
$env:PORT = "$Port"
$server = Start-Process `
  -FilePath "node" `
  -ArgumentList "tools\sync-proxy-mock\server.js" `
  -WorkingDirectory (Get-Location) `
  -WindowStyle Hidden `
  -PassThru
$env:PORT = $previousPort

Start-Sleep -Seconds 1
adb reverse "tcp:$Port" "tcp:$Port" | Out-Null

if (-not $SkipBuild) {
  flutter build apk --flavor development --debug `
    "--dart-define=GSC_SYNC_ENABLE_NETWORK=true" `
    "--dart-define=GSC_SYNC_BASE_URL=$BaseUrl"
}

adb install -r "build\app\outputs\flutter-apk\app-development-debug.apk"

Write-Host "sync-proxy mock is running. PID: $($server.Id)"
Write-Host "ADB reverse: device tcp:$Port -> host tcp:$Port"
Write-Host "Installed debug APK with GSC_SYNC_BASE_URL=$BaseUrl"
Write-Host "Manual check: open Settings/Profile -> Sync Status -> tap Sync Now -> open Sync Logs -> verify notes/error details."
