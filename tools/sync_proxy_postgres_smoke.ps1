param(
  [string]$PostgresUrl = "postgres://postgres:postgres@127.0.0.1:5432/gscappall_sync_smoke",
  [string]$DatabaseName = "gscappall_sync_smoke",
  [string]$PostgresUser = "postgres",
  [string]$PostgresPassword = "postgres",
  [string]$PostgresHost = "127.0.0.1"
)

$ErrorActionPreference = "Stop"

$psql = Get-Command psql -ErrorAction SilentlyContinue
if (-not $psql) {
  $defaultPsql = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
  if (Test-Path $defaultPsql) {
    $psql = @{ Source = $defaultPsql }
  } else {
    throw "psql is not available. Install PostgreSQL 17 or add psql to PATH."
  }
}

$npm = Get-Command npm -ErrorAction SilentlyContinue
if (-not $npm) {
  $defaultNpm = "C:\Program Files\nodejs\npm.cmd"
  if (Test-Path $defaultNpm) {
    $npm = @{ Source = $defaultNpm }
  } else {
    throw "npm is not available. Install Node.js LTS or add npm to PATH."
  }
}

$previousPgPassword = $env:PGPASSWORD
$previousStore = $env:SYNC_PROXY_STORE
$previousPostgresUrl = $env:SYNC_PROXY_POSTGRES_URL
$repoRoot = Split-Path -Parent $PSScriptRoot
$proxyDir = Join-Path $repoRoot "tools\sync-proxy"
$formalSmoke = Join-Path $repoRoot "tools\sync_proxy_formal_smoke.ps1"

try {
  $env:PGPASSWORD = $PostgresPassword
  Push-Location $proxyDir
  try {
    & $npm.Source install
  } finally {
    Pop-Location
  }

  & $psql.Source -h $PostgresHost -U $PostgresUser -d postgres -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DatabaseName' AND pid <> pg_backend_pid();" | Out-Host
  & $psql.Source -h $PostgresHost -U $PostgresUser -d postgres -c "DROP DATABASE IF EXISTS $DatabaseName;" | Out-Host
  & $psql.Source -h $PostgresHost -U $PostgresUser -d postgres -c "CREATE DATABASE $DatabaseName;" | Out-Host

  $env:SYNC_PROXY_STORE = "postgres"
  $env:SYNC_PROXY_POSTGRES_URL = $PostgresUrl
  powershell -ExecutionPolicy Bypass -File $formalSmoke
} finally {
  $env:PGPASSWORD = $previousPgPassword
  $env:SYNC_PROXY_STORE = $previousStore
  $env:SYNC_PROXY_POSTGRES_URL = $previousPostgresUrl
}
