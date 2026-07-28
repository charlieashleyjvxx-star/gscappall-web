param(
  [string]$Serial,
  [switch]$SkipBuild,
  [switch]$SkipInstall,
  [switch]$NoArchive
)

$ErrorActionPreference = "Stop"

function Resolve-DeviceSerial {
  if ($Serial) {
    return $Serial
  }

  $devices = adb devices |
    Select-String -Pattern "^\S+\s+device$" |
    ForEach-Object { ($_.Line -split "\s+")[0] }

  if ($devices.Count -eq 1) {
    return $devices[0]
  }
  if ($devices.Count -eq 0) {
    throw "No Android device is online. Connect a device or pass -Serial explicitly."
  }
  throw "Multiple Android devices are online. Pass -Serial explicitly: $($devices -join ', ')"
}

$resolvedSerial = Resolve-DeviceSerial
$arguments = @(
  "-ExecutionPolicy", "Bypass",
  "-File", "tools\android_reading_regression.ps1",
  "-Serial", $resolvedSerial,
  "-ShortSuite"
)

if ($SkipBuild) {
  $arguments += "-SkipBuild"
}
if ($SkipInstall) {
  $arguments += "-SkipInstall"
}
if (-not $NoArchive) {
  $arguments += "-ArchiveArtifacts"
}

Write-Host "Running Android short suite on $resolvedSerial..."
& powershell @arguments
if ($LASTEXITCODE -ne 0) {
  throw "Android short suite failed on $resolvedSerial."
}
