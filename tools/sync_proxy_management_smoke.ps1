$ErrorActionPreference = "Stop"

$repo = Split-Path -Parent $PSScriptRoot
$db = Join-Path $env:TEMP "gsc_sync_proxy_management_smoke.sqlite"
if (Test-Path $db) {
  Remove-Item -LiteralPath $db -Force
}

function Start-SyncProxy {
  param(
    [int]$Port,
    [string]$DatabasePath,
    [int]$RateLimit = 80
  )

  $env:PORT = "$Port"
  $env:SYNC_PROXY_DB = $DatabasePath
  $env:SYNC_PROXY_REQUIRE_AUTH = "true"
  $env:SYNC_PROXY_RATE_LIMIT_MAX = "$RateLimit"
  $env:SYNC_PROXY_RATE_LIMIT_WINDOW_MS = "60000"
  Start-Process -FilePath node -ArgumentList "tools\sync-proxy\server.js" `
    -WorkingDirectory $repo -PassThru -WindowStyle Hidden
}

function Invoke-JsonPost {
  param(
    [string]$Uri,
    [object]$Body,
    [hashtable]$Headers = @{}
  )
  Invoke-RestMethod -Uri $Uri -Method Post -ContentType "application/json" `
    -Headers $Headers -Body ($Body | ConvertTo-Json -Depth 20)
}

$port = 8793
$server = Start-SyncProxy -Port $port -DatabasePath $db
try {
  $base = "http://127.0.0.1:$port"
  $ready = $false
  for ($attempt = 0; $attempt -lt 120; $attempt += 1) {
    try {
      Invoke-RestMethod -Uri "$base/health" -Method Get -TimeoutSec 5 | Out-Null
      $ready = $true
      break
    } catch {
      Start-Sleep -Milliseconds 500
    }
  }
  if (-not $ready) {
    throw "sync-proxy did not become ready on port $port."
  }
  $accountId = "management-smoke"
  $password = "management-pass"

  $register = Invoke-JsonPost "$base/auth/register" @{
    accountId = $accountId
    password = $password
    profileIds = @(1, 2)
  }

  $login = Invoke-JsonPost "$base/auth/login" @{
    accountId = $accountId
    password = $password
  }

  $headers = @{
    Authorization = "Bearer $($login.accessToken)"
    "X-GSC-Account-Id" = $accountId
    "X-GSC-Device-Id" = "management-device"
    "X-GSC-Profile-Ids" = "1,2"
    "X-GSC-Request-Id" = "management-push"
  }

  $push = Invoke-JsonPost "$base/sync/push" @{
    requestId = "management-push"
    device = @{
      deviceId = "management-device"
      platform = "smoke"
      appVersion = "0.1-smoke"
      schemaVersion = 10
    }
    checkpoint = @{
      globalCursor = $null
      collectionCursors = @{}
      schemaVersion = 10
    }
    batch = @{
      favorites = @(
        @{
          profileId = 1
          poemId = 1
          isFavorite = $true
          metadata = @{
            localId = "favorite:1:1"
            updatedAt = "2026-05-11T00:00:00.000Z"
          }
        }
      )
    }
    generatedAt = "2026-05-11T00:00:00.000Z"
  } -Headers $headers

  $logs = Invoke-RestMethod -Uri "$base/debug/request-logs?limit=10&requestId=management-push" `
    -Method Get -Headers $headers
  if ($logs.items.Count -lt 1) {
    throw "request log query returned no items"
  }

  $successLogs = Invoke-RestMethod -Uri "$base/debug/request-logs?limit=10&statusCode=200" `
    -Method Get -Headers $headers
  if ($successLogs.items.Count -lt 1) {
    throw "statusCode filter returned no items"
  }

  $prune = Invoke-JsonPost "$base/debug/request-logs/prune" @{
    retain = 5
  } -Headers $headers
  if (-not $prune.ok) {
    throw "request log prune failed"
  }

  $logout = Invoke-JsonPost "$base/auth/logout" @{
    revokeAll = $false
  } -Headers $headers
  if (-not $logout.revoked) {
    throw "logout did not revoke token"
  }

  Write-Host "management smoke passed: register=$($register.accountId), pushRequest=$($push.requestId), logs=$($logs.items.Count)"
} finally {
  if ($server -and -not $server.HasExited) {
    Stop-Process -Id $server.Id -Force
  }
}

$rateDb = Join-Path $env:TEMP "gsc_sync_proxy_rate_smoke.sqlite"
if (Test-Path $rateDb) {
  Remove-Item -LiteralPath $rateDb -Force
}
$ratePort = 8794
$rateServer = Start-SyncProxy -Port $ratePort -DatabasePath $rateDb -RateLimit 2
try {
  $rateBase = "http://127.0.0.1:$ratePort"
  $ready = $false
  for ($attempt = 0; $attempt -lt 120; $attempt += 1) {
    try {
      Invoke-RestMethod -Uri "$rateBase/health" -Method Get -TimeoutSec 5 | Out-Null
      $ready = $true
      break
    } catch {
      Start-Sleep -Milliseconds 500
    }
  }
  if (-not $ready) {
    throw "sync-proxy did not become ready on port $ratePort."
  }
  Invoke-RestMethod -Uri "$rateBase/health" -Method Get | Out-Null
  try {
    Invoke-RestMethod -Uri "$rateBase/health" -Method Get | Out-Null
    throw "rate limit did not trigger"
  } catch {
    if ($_.Exception.Response.StatusCode.value__ -ne 429) {
      throw
    }
  }
  Write-Host "rate limit smoke passed"
} finally {
  if ($rateServer -and -not $rateServer.HasExited) {
    Stop-Process -Id $rateServer.Id -Force
  }
}
