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

$symbolDirectory = "build/symbols/$Flavor"

flutter build apk `
  --flavor $Flavor `
  --release `
  --split-per-abi `
  --obfuscate `
  --split-debug-info=$symbolDirectory
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

flutter build appbundle `
  --flavor $Flavor `
  --release `
  --obfuscate `
  --split-debug-info=$symbolDirectory
exit $LASTEXITCODE
