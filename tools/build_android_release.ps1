param(
  [ValidateSet('development', 'staging', 'production')]
  [string]$Flavor = 'production',
  [switch]$SkipTests
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

if (-not $SkipTests) {
  flutter analyze
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  flutter test --no-pub
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$releaseId = "$Flavor-$((Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ'))"
$symbolDirectory = "build/symbols/$Flavor/$releaseId"

flutter build apk `
  --flavor $Flavor `
  --release `
  --split-per-abi `
  --obfuscate `
  --dart-define=GSC_RELEASE_ID=$releaseId `
  --split-debug-info=$symbolDirectory
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

flutter build appbundle `
  --flavor $Flavor `
  --release `
  --obfuscate `
  --dart-define=GSC_RELEASE_ID=$releaseId `
  --split-debug-info=$symbolDirectory
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$manifest = [ordered]@{
  releaseId = $releaseId
  flavor = $Flavor
  createdAtUtc = (Get-Date).ToUniversalTime().ToString('o')
  symbolDirectory = (Resolve-Path $symbolDirectory).Path
  symbolizeCommand = "flutter symbolize -i <stack-trace.txt> -d $symbolDirectory/app.android-arm64.symbols"
}
$manifest | ConvertTo-Json | Set-Content -LiteralPath "$symbolDirectory/release-manifest.json" -Encoding UTF8
Write-Host "Release ID: $releaseId"
Write-Host "Symbols: $symbolDirectory"
