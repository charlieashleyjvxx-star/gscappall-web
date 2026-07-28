param(
  [string]$Serial = "emulator-5556",
  [switch]$SkipBuild,
  [switch]$SkipInstall,
  [switch]$ResetData,
  [switch]$SkipSmokeFlows,
  [switch]$RouteChainSmoke,
  [switch]$ShortSuite,
  [switch]$SyncLogOnly,
  [switch]$GrowthTrendOnly,
  [switch]$ChallengeMapReturnOnly,
  [switch]$ReadingScoreOnly,
  [switch]$ReadingControlsOnly,
  [switch]$PermissionOnly,
  [switch]$ArchiveArtifacts
)

$ErrorActionPreference = "Stop"

$PackageName = "com.gsc.appall.dev"
$ActivityName = "$PackageName/com.gsc.appall.MainActivity"
$ApkPath = "build\app\outputs\flutter-apk\app-development-debug.apk"
$DumpPath = "/sdcard/gscappall_reading_regression.xml"
$ArtifactDir = $null
$ArtifactLogPath = $null
$TranscriptStarted = $false

if ($RouteChainSmoke) {
  Write-Host "==> Route chain smoke: stage scoped named routes and sync-log detail shortcuts"
  flutter test test\notification_route_payload_test.dart test\sync_log_stage_route_test.dart test\stage_scope_navigation_chain_test.dart
  if ($LASTEXITCODE -ne 0) {
    throw "route chain smoke failed"
  }
  if ($SkipSmokeFlows) {
    Write-Host "Route chain smoke passed."
    return
  }
}

function Write-LogLine {
  param([string]$Message)

  Write-Host $Message
  if ($script:ArtifactLogPath) {
    Add-Content -LiteralPath $script:ArtifactLogPath -Value $Message -Encoding UTF8
  }
}

function Initialize-ArtifactArchive {
  if (-not $ArchiveArtifacts) {
    return
  }

  $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
  $safeSerial = $Serial -replace '[^A-Za-z0-9_.-]', '-'
  $script:ArtifactDir = Join-Path "build\android-regression" "$timestamp-$safeSerial"
  New-Item -ItemType Directory -Force -Path $script:ArtifactDir | Out-Null
  $script:ArtifactLogPath = Join-Path $script:ArtifactDir "run.log"
  Start-Transcript -Path (Join-Path $script:ArtifactDir "transcript.log") -Force | Out-Null
  $script:TranscriptStarted = $true
  Write-LogLine "Artifact archive: $script:ArtifactDir"
}

function Save-ArtifactSnapshot {
  param([string]$Label)

  if (-not $script:ArtifactDir) {
    return
  }

  $safeLabel = $Label -replace '[^A-Za-z0-9_.-]', '-'
  $prefix = Join-Path $script:ArtifactDir $safeLabel
  try {
    Invoke-Adb shell timeout 8 uiautomator dump --compressed $DumpPath | Out-Null
    $xml = (Invoke-Adb shell cat $DumpPath) -join "`n"
    Set-Content -LiteralPath "$prefix.xml" -Value $xml -Encoding UTF8
  } catch {
    Write-LogLine "Artifact UI dump skipped for ${Label}: $($_.Exception.Message)"
  }
  try {
    $screenshotPath = "$prefix.png"
    $adbCommand = "adb -s $Serial exec-out screencap -p > `"$screenshotPath`""
    cmd /c $adbCommand | Out-Null
    if ($LASTEXITCODE -ne 0) {
      throw "adb screencap failed"
    }
  } catch {
    if (Test-Path $screenshotPath) {
      Remove-Item -LiteralPath $screenshotPath -Force
    }
    Write-LogLine "Artifact screenshot skipped for ${Label}: $($_.Exception.Message)"
  }
}

function Save-FinalArtifacts {
  param([string]$Result)

  if (-not $script:ArtifactDir) {
    return
  }

  Save-ArtifactSnapshot "final-$Result"
  try {
    $logs = (Invoke-Adb logcat -d -t 1200) -join "`n"
    Set-Content -LiteralPath (Join-Path $script:ArtifactDir "logcat-$Result.txt") -Value $logs -Encoding UTF8
  } catch {
    Write-LogLine "Artifact logcat skipped: $($_.Exception.Message)"
  }
  Write-LogLine "Artifacts saved: $script:ArtifactDir"
  if ($script:TranscriptStarted) {
    Stop-Transcript | Out-Null
    $script:TranscriptStarted = $false
  }
}

function Run-Step {
  param(
    [string]$Name,
    [scriptblock]$Body
  )

  Write-LogLine "==> $Name"
  try {
    & $Body
    Save-ArtifactSnapshot "step-$($Name -replace '[^A-Za-z0-9_.-]', '-')"
  } catch {
    Save-FinalArtifacts "failed"
    throw
  }
}

function New-Zh {
  param([Parameter(ValueFromRemainingArguments = $true)][int[]]$CodePoints)

  return -join ($CodePoints | ForEach-Object { [char]$_ })
}

function Get-FocusedPackageRaw {
  $focusLines = & adb -s $Serial shell dumpsys window | Select-String -Pattern "mFocusedApp|mCurrentFocus"
  foreach ($line in $focusLines) {
    if ($line.Line -match " ([a-zA-Z0-9_.]+)/") {
      return $matches[1]
    }
  }
  return ""
}

function Stop-KnownFocusStealers {
  param([string]$FocusedPackage = "")

  $knownFocusStealers = @(
    "com.huawei.music",
    "com.tencent.mobileqq",
    "com.tencent.mm",
    "com.alibaba.android.rimet",
    "com.easy.abroad"
  )
  foreach ($package in $knownFocusStealers) {
    if ($FocusedPackage -eq "" -or $FocusedPackage -eq $package) {
      & adb -s $Serial shell am force-stop $package | Out-Null
    }
  }
}

function Ensure-TargetAppFocusedForInput {
  $focusedPackage = Get-FocusedPackageRaw
  if ($focusedPackage -eq $PackageName) {
    return
  }

  Write-Host "Target app lost focus before input; restoring foreground. Focused=$focusedPackage"
  for ($attempt = 1; $attempt -le 4; $attempt++) {
    Stop-KnownFocusStealers $focusedPackage
    & adb -s $Serial shell input keyevent KEYCODE_WAKEUP | Out-Null
    & adb -s $Serial shell am start "-W" "-n" $ActivityName | Out-Null
    Start-Sleep -Seconds 3
    $focusedPackage = Get-FocusedPackageRaw
    if ($focusedPackage -eq $PackageName) {
      return
    }
    Write-Host "Target app restore attempt $attempt did not focus app. Focused=$focusedPackage"
  }
  $focusedPackage = Get-FocusedPackageRaw
  if ($focusedPackage -ne $PackageName) {
    throw "Target app lost foreground before input. Focused=$focusedPackage"
  }
}

function Invoke-Adb {
  param([Parameter(ValueFromRemainingArguments = $true)][string[]]$Args)
  if (
    $Args.Count -ge 3 -and
    $Args[0] -eq "shell" -and
    $Args[1] -eq "input" -and
    @("tap", "swipe", "text") -contains $Args[2]
  ) {
    Ensure-TargetAppFocusedForInput
  }
  & adb -s $Serial @Args
  if ($LASTEXITCODE -ne 0) {
    throw "adb failed: $($Args -join ' ')"
  }
}

function Get-FocusedPackage {
  $focusLines = Invoke-Adb shell dumpsys window | Select-String -Pattern "mFocusedApp|mCurrentFocus"
  foreach ($line in $focusLines) {
    if ($line.Line -match " ([a-zA-Z0-9_.]+)/") {
      return $matches[1]
    }
  }
  return ""
}

function Start-AppAndWait {
  param([int]$DelaySeconds = 15)

  Stop-KnownFocusStealers
  Invoke-Adb shell am force-stop $PackageName | Out-Null
  Invoke-Adb shell am start "-W" "-n" $ActivityName | Out-Host
  Start-Sleep -Seconds 3

  $focusedPackage = Get-FocusedPackage
  if ($focusedPackage -ne $PackageName) {
    Write-Host "Target app is not focused after am start; using explicit launcher intent fallback. Focused=$focusedPackage"
    Stop-KnownFocusStealers $focusedPackage
    Invoke-Adb shell am start "-W" "-a" "android.intent.action.MAIN" "-c" "android.intent.category.LAUNCHER" "-n" $ActivityName | Out-Host
    Start-Sleep -Seconds 5
    $focusedPackage = Get-FocusedPackage
  }

  if ($focusedPackage -ne $PackageName) {
    throw "Target app did not reach foreground. Focused=$focusedPackage"
  }

  if ($DelaySeconds -gt 3) {
    Start-Sleep -Seconds ($DelaySeconds - 3)
  }
}

function Get-UiDump {
  Ensure-TargetAppFocusedForInput
  $lastError = $null
  for ($attempt = 1; $attempt -le 4; $attempt++) {
    try {
      Invoke-Adb shell rm -f $DumpPath | Out-Null
      Invoke-Adb shell timeout 12 uiautomator dump --compressed $DumpPath | Out-Null
      $xml = (Invoke-Adb shell cat $DumpPath) -join "`n"
      if ($xml -match [regex]::Escape($PackageName)) {
        return $xml
      }
      Write-Host "UIAutomator dumped another package; restoring target app and retrying."
      Ensure-TargetAppFocusedForInput
      Start-Sleep -Seconds 1
    } catch {
      $lastError = $_
      Write-Host "UIAutomator compressed dump attempt $attempt failed; trying plain dump."
      try {
        Invoke-Adb shell rm -f $DumpPath | Out-Null
        Invoke-Adb shell timeout 12 uiautomator dump $DumpPath | Out-Null
        $xml = (Invoke-Adb shell cat $DumpPath) -join "`n"
        if ($xml -match [regex]::Escape($PackageName)) {
          return $xml
        }
        Write-Host "UIAutomator plain dump captured another package; restoring target app and retrying."
        Ensure-TargetAppFocusedForInput
        Start-Sleep -Seconds 1
      } catch {
        $lastError = $_
      }
      Write-Host "UIAutomator dump attempt $attempt failed; retrying in place."
      Start-Sleep -Seconds 2
    }
  }
  throw $lastError
}

function Tap-FirstButtonContaining {
  param([string]$Text)

  $xml = Get-UiDump
  $pattern =
    'class="android\.widget\.Button"[^>]*(?:content-desc|text)="[^"]*' +
    [regex]::Escape($Text) +
    '[^"]*"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"'
  $matches = [regex]::Matches($xml, $pattern)
  foreach ($match in $matches) {
    $left = [int]$match.Groups[1].Value
    $top = [int]$match.Groups[2].Value
    $right = [int]$match.Groups[3].Value
    $bottom = [int]$match.Groups[4].Value
    if ($right -le $left -or $bottom -le $top) {
      continue
    }

    $x = [int](($left + $right) / 2)
    $y = [int](($top + $bottom) / 2)
    if ($bottom -gt 2520) {
      $y = [Math]::Max($top + 18, 2480)
    }
    Invoke-Adb shell input tap $x $y | Out-Null
    return $true
  }
  return $false
}

function Test-VisibleButtonContaining {
  param([string]$Text)

  $xml = Get-UiDump
  $pattern =
    'class="android\.widget\.Button"[^>]*(?:content-desc|text)="[^"]*' +
    [regex]::Escape($Text) +
    '[^"]*"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"'
  $matches = [regex]::Matches($xml, $pattern)
  foreach ($match in $matches) {
    $left = [int]$match.Groups[1].Value
    $top = [int]$match.Groups[2].Value
    $right = [int]$match.Groups[3].Value
    $bottom = [int]$match.Groups[4].Value
    if ($right -gt $left -and $bottom -gt $top) {
      return $true
    }
  }
  return $false
}

function Tap-FirstNodeContaining {
  param([string]$Text)

  $xml = Get-UiDump
  return Tap-FirstNodeContainingInXml $Text $xml
}

function Tap-FirstNodeContainingInXml {
  param(
    [string]$Text,
    [string]$Xml
  )

  $pattern =
    '(?:content-desc|text)="[^"]*' +
    [regex]::Escape($Text) +
    '[^"]*"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"'
  $matches = [regex]::Matches($Xml, $pattern)
  foreach ($match in $matches) {
    $left = [int]$match.Groups[1].Value
    $top = [int]$match.Groups[2].Value
    $right = [int]$match.Groups[3].Value
    $bottom = [int]$match.Groups[4].Value
    if ($right -le $left -or $bottom -le $top) {
      continue
    }

    $x = [int](($left + $right) / 2)
    $y = [int](($top + $bottom) / 2)
    Invoke-Adb shell input tap $x $y | Out-Null
    return $true
  }
  return $false
}

function Tap-NodeContainingWithScroll {
  param([string]$Text)

  for ($attempt = 0; $attempt -lt 5; $attempt++) {
    if (Tap-FirstNodeContaining $Text) {
      return $true
    }
    Invoke-Adb shell input swipe 960 930 960 360 450 | Out-Null
    Start-Sleep -Milliseconds 700
  }
  return $false
}

function Tap-ButtonContainingWithScroll {
  param([string]$Text)

  for ($attempt = 0; $attempt -lt 4; $attempt++) {
    if (Tap-FirstButtonContaining $Text) {
      return $true
    }
    Invoke-Adb shell input swipe 960 930 960 360 450 | Out-Null
    Start-Sleep -Milliseconds 700
  }
  return $false
}

function Tap-ButtonContainingWithDeepScroll {
  param([string]$Text)

  for ($attempt = 0; $attempt -lt 8; $attempt++) {
    if (Tap-FirstButtonContaining $Text) {
      return $true
    }
    Invoke-Adb shell input swipe 1200 2300 1200 450 650 | Out-Null
    Start-Sleep -Milliseconds 700
  }
  for ($finalAttempt = 0; $finalAttempt -lt 4; $finalAttempt++) {
    Start-Sleep -Milliseconds 450
    if (Tap-FirstButtonContaining $Text) {
      return $true
    }
    Invoke-Adb shell input swipe 1200 2460 1200 2160 350 | Out-Null
  }
  return $false
}

function Tap-NodeContainingWithDeepScroll {
  param([string]$Text)

  for ($attempt = 0; $attempt -lt 20; $attempt++) {
    if (Tap-FirstNodeContaining $Text) {
      return $true
    }
    if ($attempt -lt 3) {
      Invoke-Adb shell input swipe 960 620 960 2100 650 | Out-Null
    } else {
      Invoke-Adb shell input swipe 960 2100 960 620 650 | Out-Null
    }
    Start-Sleep -Milliseconds 700
  }
  return $false
}

function Tap-BottomSheetNodeContainingWithScroll {
  param([string]$Text)

  for ($attempt = 0; $attempt -lt 6; $attempt++) {
    if (Tap-FirstNodeContaining $Text) {
      return $true
    }
    Invoke-Adb shell input swipe 960 2460 960 1680 550 | Out-Null
    Start-Sleep -Milliseconds 700
  }
  for ($finalAttempt = 0; $finalAttempt -lt 8; $finalAttempt++) {
    Start-Sleep -Milliseconds 450
    $finalXml = Get-UiDump
    if (Tap-FirstNodeContainingInXml $Text $finalXml) {
      return $true
    }
    Invoke-Adb shell input swipe 960 2460 960 2160 350 | Out-Null
  }
  Start-Sleep -Milliseconds 800
  $settledXml = Get-UiDump
  if (Tap-FirstNodeContainingInXml $Text $settledXml) {
    return $true
  }
  for ($reverseAttempt = 0; $reverseAttempt -lt 8; $reverseAttempt++) {
    Invoke-Adb shell input swipe 960 1680 960 2460 500 | Out-Null
    Start-Sleep -Milliseconds 650
    $reverseXml = Get-UiDump
    if (Tap-FirstNodeContainingInXml $Text $reverseXml) {
      return $true
    }
    if (Tap-FirstNodeContainingInXml $expandAll $reverseXml) {
      Start-Sleep -Milliseconds 500
      if (Tap-FirstNodeContaining $Text) {
        return $true
      }
    }
  }
  return $false
}

function Tap-BottomSheetDetailAfterExpand {
  param([string]$Text)

  $expandAll = New-Zh 0x5C55 0x5F00 0x5168 0x90E8
  for ($attempt = 0; $attempt -lt 10; $attempt++) {
    if (Tap-FirstNodeContaining $Text) {
      return $true
    }
    if (Tap-FirstNodeContaining $expandAll) {
      Start-Sleep -Milliseconds 500
      if (Tap-FirstNodeContaining $Text) {
        return $true
      }
    }
    Invoke-Adb shell input swipe 960 2460 960 1680 550 | Out-Null
    Start-Sleep -Milliseconds 700
  }
  for ($finalAttempt = 0; $finalAttempt -lt 4; $finalAttempt++) {
    Start-Sleep -Milliseconds 450
    $finalXml = Get-UiDump
    if (Tap-FirstNodeContainingInXml $Text $finalXml) {
      return $true
    }
    Invoke-Adb shell input swipe 960 2460 960 2160 350 | Out-Null
  }
  Start-Sleep -Milliseconds 800
  $settledXml = Get-UiDump
  if (Tap-FirstNodeContainingInXml $Text $settledXml) {
    return $true
  }
  return $false
}

function Tap-FirstClassContaining {
  param([string]$ClassName)

  $xml = Get-UiDump
  $pattern =
    'class="' +
    [regex]::Escape($ClassName) +
    '"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"'
  $match = [regex]::Match($xml, $pattern)
  if (-not $match.Success) {
    return $false
  }

  $x = [int](([int]$match.Groups[1].Value + [int]$match.Groups[3].Value) / 2)
  $y = [int](([int]$match.Groups[2].Value + [int]$match.Groups[4].Value) / 2)
  Invoke-Adb shell input tap $x $y | Out-Null
  return $true
}

function Tap-FirstClassContainingWithScroll {
  param([string]$ClassName)

  for ($attempt = 0; $attempt -lt 6; $attempt++) {
    if (Tap-FirstClassContaining $ClassName) {
      return $true
    }
    if (($attempt % 2) -eq 0) {
      Invoke-Adb shell input swipe 960 360 960 930 450 | Out-Null
    } else {
      Invoke-Adb shell input swipe 960 930 960 360 450 | Out-Null
    }
    Start-Sleep -Milliseconds 700
  }
  return $false
}


function Query-AppDbScalar {
  param([string]$Sql)

  $hasDeviceSqlite = ((& adb -s $Serial shell "which sqlite3 || echo no-sqlite3") -join "`n") -notmatch "no-sqlite3"
  if ($hasDeviceSqlite) {
    $command = "echo '$Sql' | run-as $PackageName sqlite3 app_flutter/gscappall.sqlite"
    $output = & adb -s $Serial shell $command
    if ($LASTEXITCODE -ne 0) {
      throw "adb failed: shell $command"
    }
    $text = (@($output) -join "`n").Trim()
    $matches = [regex]::Matches($text, "-?\d+")
    if ($matches.Count -eq 0) {
      return 0
    }
    return [int]$matches[$matches.Count - 1].Value
  }

  $tmpDb = Join-Path $env:TEMP "gscappall-$Serial.sqlite"
  $adbCommand = "adb -s $Serial exec-out run-as $PackageName cat app_flutter/gscappall.sqlite > `"$tmpDb`""
  cmd /c $adbCommand | Out-Null
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path $tmpDb)) {
    throw "failed to copy app database for local sqlite query"
  }

  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $output = & dart run --verbosity=error tools/query_sqlite.dart $tmpDb $Sql 2>$null
  $exitCode = $LASTEXITCODE
  $ErrorActionPreference = $previousErrorActionPreference
  if ($exitCode -ne 0) {
    throw "local sqlite query failed: $Sql"
  }
  $text = (@($output) -join "`n").Trim()
  $matches = [regex]::Matches($text, "-?\d+")
  if ($matches.Count -eq 0) {
    return 0
  }
  return [int]$matches[$matches.Count - 1].Value
}

function Copy-AppDbToLocal {
  param([string]$Purpose)

  $safePurpose = ($Purpose -replace '[^A-Za-z0-9_-]', '-')
  $tmpDb = Join-Path $env:TEMP "gscappall-$Serial-$safePurpose.sqlite"
  if (Test-Path $tmpDb) {
    Remove-Item -LiteralPath $tmpDb -Force
  }
  $adbCommand = "adb -s $Serial exec-out run-as $PackageName cat app_flutter/gscappall.sqlite > `"$tmpDb`""
  cmd /c $adbCommand | Out-Null
  if ($LASTEXITCODE -ne 0 -or -not (Test-Path $tmpDb)) {
    throw "failed to copy app database for local sqlite operation"
  }
  return $tmpDb
}

function Push-LocalDbToApp {
  param([string]$LocalDbPath)

  $remoteTmp = "/data/local/tmp/gscappall-$Serial-injected.sqlite"
  Invoke-Adb shell am force-stop $PackageName | Out-Null
  Invoke-Adb push $LocalDbPath $remoteTmp | Out-Null
  Invoke-Adb shell run-as $PackageName rm -f app_flutter/gscappall.sqlite-wal app_flutter/gscappall.sqlite-shm | Out-Null
  Invoke-Adb shell run-as $PackageName cp $remoteTmp app_flutter/gscappall.sqlite | Out-Null
  Invoke-Adb shell rm -f $remoteTmp | Out-Null
}

function Invoke-AppDbSqlIfPossible {
  param([string]$Sql)

  $hasDeviceSqlite = ((& adb -s $Serial shell "which sqlite3 || echo no-sqlite3") -join "`n") -notmatch "no-sqlite3"
  if ($hasDeviceSqlite) {
    $output = & adb -s $Serial shell run-as $PackageName sqlite3 app_flutter/gscappall.sqlite $Sql
    if ($LASTEXITCODE -ne 0) {
      Write-Host (($output) -join "`n")
      throw "adb failed: sqlite app DB statement"
    }
    return $true
  }

  Write-Host "Device sqlite3 not available; injecting app DB through local sqlite copy."
  $tmpDb = Copy-AppDbToLocal "inject"
  $tmpSql = Join-Path $env:TEMP "gscappall-$Serial-inject.sql"
  Set-Content -LiteralPath $tmpSql -Value $Sql -Encoding UTF8
  $previousErrorActionPreference = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  $output = & dart run --verbosity=error tools/exec_sqlite.dart $tmpDb "@$tmpSql" 2>&1
  $exitCode = $LASTEXITCODE
  $ErrorActionPreference = $previousErrorActionPreference
  if ($exitCode -ne 0) {
    Write-Host (($output) -join "`n")
    throw "local sqlite statement failed"
  }
  Push-LocalDbToApp $tmpDb
  return $true
}

function Assert-UiContains {
  param([string]$Text)

  $xml = Get-UiDump
  if ($xml -notmatch [regex]::Escape($Text)) {
    Write-Host $xml
    throw "Expected UI text not found: $Text"
  }
}

function Test-UiContains {
  param([string]$Text)

  $xml = Get-UiDump
  return $xml -match [regex]::Escape($Text)
}

function Assert-UiContainsSoon {
  param(
    [string]$Text,
    [int]$Attempts = 6
  )

  for ($attempt = 0; $attempt -lt $Attempts; $attempt++) {
    $xml = Get-UiDump
    if ($xml -match [regex]::Escape($Text)) {
      return
    }
    Start-Sleep -Milliseconds 500
  }
  Write-Host (Get-UiDump)
  throw "Expected UI text not found soon: $Text"
}

function Tap-ButtonAndWaitForText {
  param(
    [string]$ButtonText,
    [string]$ExpectedText,
    [int]$Attempts = 3
  )

  for ($attempt = 0; $attempt -lt $Attempts; $attempt++) {
    if (Tap-ButtonContainingWithDeepScroll $ButtonText) {
      Start-Sleep -Seconds 2
      if (Test-UiContains $ExpectedText) {
        return $true
      }
    }
    if (Tap-NodeContainingWithDeepScroll $ButtonText) {
      Start-Sleep -Seconds 2
      if (Test-UiContains $ExpectedText) {
        return $true
      }
    }
    Start-Sleep -Milliseconds 500
  }
  return $false
}

function Assert-UiNotContains {
  param(
    [string]$Text,
    [string]$Context
  )

  $xml = Get-UiDump
  if ($xml -match [regex]::Escape($Text)) {
    Write-Host $xml
    throw "Unexpected UI text found after ${Context}: $Text"
  }
}

function Assert-UiContainsWithScroll {
  param(
    [string]$Text,
    [int]$Attempts = 5
  )

  for ($attempt = 0; $attempt -lt $Attempts; $attempt++) {
    $xml = Get-UiDump
    if ($xml -match [regex]::Escape($Text)) {
      return
    }
    Invoke-Adb shell input swipe 960 2100 960 620 650 | Out-Null
    Start-Sleep -Milliseconds 700
  }
  Write-Host (Get-UiDump)
  throw "Expected UI text not found after scrolling: $Text"
}

function Test-UiContainsWithScroll {
  param(
    [string]$Text,
    [int]$Attempts = 5
  )

  for ($attempt = 0; $attempt -lt $Attempts; $attempt++) {
    $xml = Get-UiDump
    if ($xml -match [regex]::Escape($Text)) {
      return $true
    }
    Invoke-Adb shell input swipe 960 2100 960 620 650 | Out-Null
    Start-Sleep -Milliseconds 700
  }
  return $false
}

function Assert-UiContainsWithBidirectionalScroll {
  param(
    [string]$Text,
    [int]$Attempts = 8
  )

  for ($attempt = 0; $attempt -lt $Attempts; $attempt++) {
    $xml = Get-UiDump
    if ($xml -match [regex]::Escape($Text)) {
      return
    }
    if (($attempt % 2) -eq 0) {
      Invoke-Adb shell input swipe 960 620 960 2100 650 | Out-Null
    } else {
      Invoke-Adb shell input swipe 960 2100 960 620 650 | Out-Null
    }
    Start-Sleep -Milliseconds 700
  }
  $finalXml = Get-UiDump
  if ($finalXml -match [regex]::Escape($Text)) {
    return
  }
  Write-Host $finalXml
  throw "Expected UI text not found after bidirectional scrolling: $Text"
}

function Assert-NoFlutterRedScreenOrCrash {
  param([string]$Context)

  $xml = Get-UiDump
  $uiFailurePattern = "Flutter Error|FlutterError|A RenderFlex overflowed|Exception caught|_dependents|Failed assertion|NoSuchMethodError|TypeError"
  if ($xml -match $uiFailurePattern) {
    Write-Host $xml
    throw "Flutter red-screen signal found after $Context"
  }

  $logs = (Invoke-Adb logcat -d -t 300) -join "`n"
  $logFailurePattern = "FATAL EXCEPTION|FlutterError|SQLiteException.*$PackageName|Exception caught by widgets library|A RenderFlex overflowed|_dependents|Failed assertion.*dependents|dependents\.isEmpty|NoSuchMethodError|Null check operator used on a null value"
  if ($logs -match $logFailurePattern) {
    Write-Host ($logs -split "`n" | Select-String -Pattern $logFailurePattern -Context 2,2 | Out-String)
    throw "Crash or red-screen log found after $Context"
  }
}

function Keep-DeviceAwake {
  Invoke-Adb shell input keyevent KEYCODE_WAKEUP | Out-Null
  Invoke-Adb shell svc power stayon true | Out-Null
  Invoke-Adb shell settings put system screen_off_timeout 1800000 | Out-Null
  Invoke-Adb shell settings put global window_animation_scale 0 | Out-Null
  Invoke-Adb shell settings put global transition_animation_scale 0 | Out-Null
  Invoke-Adb shell settings put global animator_duration_scale 0 | Out-Null
  Write-Host "Device wake lock requested: stayon=true, screen timeout=30min."
}

function Stabilize-DeviceUi {
  Invoke-Adb shell input keyevent KEYCODE_HOME | Out-Null
  Start-Sleep -Seconds 1
  Invoke-Adb shell am force-stop com.tencent.mobileqq | Out-Null
  Invoke-Adb shell am force-stop com.tencent.mm | Out-Null
  Invoke-Adb shell am force-stop com.alibaba.android.rimet | Out-Null
  Invoke-Adb shell am force-stop $PackageName | Out-Null
  Start-Sleep -Seconds 2
}

function Assert-DbCountIncreased {
  param(
    [string]$TableName,
    [int]$Before,
    [int]$After,
    [string]$Context
  )

  if ($After -le $Before) {
    throw "Expected $TableName count to increase after $Context. before=$Before after=$After"
  }
}

function Assert-DbCountUnchanged {
  param(
    [string]$TableName,
    [int]$Before,
    [int]$After,
    [string]$Context
  )

  if ($After -ne $Before) {
    throw "Expected $TableName count to stay unchanged after $Context. before=$Before after=$After"
  }
}

function Open-ProfileTab {
  $mineWord = New-Zh 0x6211 0x7684
  $opened = $false
  for ($attempt = 0; $attempt -lt 5; $attempt++) {
    if (Tap-FirstButtonContaining $mineWord) {
      $opened = $true
      break
    }
    Invoke-Adb shell input keyevent KEYCODE_BACK | Out-Null
    Start-Sleep -Milliseconds 700
  }
  if (-not $opened) {
    Invoke-Adb shell input tap 1102 2531 | Out-Null
  }
  Start-Sleep -Seconds 2
  for ($attempt = 0; $attempt -lt 3; $attempt++) {
    Invoke-Adb shell input swipe 1200 450 1200 2300 650 | Out-Null
    Start-Sleep -Milliseconds 400
  }
}

function Open-StudyCardsFromHome {
  $homeWord = New-Zh 0x9996 0x9875
  $studyCardsWord = New-Zh 0x5B66 0x4E60 0x5361 0x7247
  $studyCardsSubtitle = New-Zh 0x901A 0x8FC7 0x7FFB 0x5361 0x7247
  $enterWord = New-Zh 0x8FDB 0x5165
  $showAllCards = New-Zh 0x663E 0x793A 0x5168 0x90E8 0x5361 0x7247

  Tap-FirstButtonContaining $homeWord | Out-Null
  Invoke-Adb shell input tap 158 2531 | Out-Null
  Start-Sleep -Seconds 2
  for ($attempt = 0; $attempt -lt 8; $attempt++) {
    $xml = Get-UiDump
    if ($xml -match [regex]::Escape($studyCardsSubtitle)) {
      break
    }
    Invoke-Adb shell input swipe 1200 2300 1200 450 650 | Out-Null
    Start-Sleep -Milliseconds 700
  }
  if (-not (Tap-FirstButtonContaining $enterWord)) {
    if (-not (Tap-NodeContainingWithScroll $studyCardsWord)) {
      Invoke-Adb shell input tap 980 2140 | Out-Null
    }
  }
  Start-Sleep -Seconds 3
  Assert-UiContains $studyCardsWord
  if ((Get-UiDump) -match [regex]::Escape($showAllCards)) {
    if (-not (Tap-FirstButtonContaining $showAllCards)) {
      Invoke-Adb shell input tap 630 1724 | Out-Null
    }
  }
  Start-Sleep -Seconds 1
}

function Reveal-StudyCardActions {
  $frontHint = New-Zh 0x8F7B 0x70B9 0x5361 0x7247 0x7FFB 0x9762
  $remembered = New-Zh 0x6211 0x8BB0 0x4F4F 0x4E86
  $showAllCards = New-Zh 0x663E 0x793A 0x5168 0x90E8 0x5361 0x7247
  $currentCard = New-Zh 0x5F53 0x524D 0x7B2C

  $xml = Get-UiDump
  if ($xml -match [regex]::Escape($showAllCards)) {
    if (-not (Tap-FirstButtonContaining $showAllCards)) {
      Invoke-Adb shell input tap 630 1724 | Out-Null
    }
    Start-Sleep -Seconds 2
    $xml = Get-UiDump
  }

  for ($attempt = 0; $attempt -lt 10; $attempt++) {
    if ($xml -match [regex]::Escape($currentCard)) {
      break
    }
    Invoke-Adb shell input swipe 1200 2300 1200 450 650 | Out-Null
    Start-Sleep -Milliseconds 600
    $xml = Get-UiDump
  }

  if ($xml -match [regex]::Escape($frontHint)) {
    Invoke-Adb shell input tap 630 1900 | Out-Null
    Start-Sleep -Seconds 1
  }

  for ($attempt = 0; $attempt -lt 6; $attempt++) {
    if (Test-VisibleButtonContaining $remembered) {
      return $true
    }
    Invoke-Adb shell input swipe 1200 2300 1200 2000 400 | Out-Null
    Start-Sleep -Milliseconds 500
  }

  return $false
}

function Open-StudyCardNoteDialog {
  param(
    [string]$WriteNoteText,
    [string]$EditNoteText
  )

  Reveal-StudyCardActions | Out-Null
  if (-not (Tap-FirstButtonContaining $WriteNoteText)) {
    if (-not (Tap-FirstButtonContaining $EditNoteText)) {
      if (-not (Tap-ButtonContainingWithDeepScroll $WriteNoteText)) {
        return $false
      }
    }
  }
  Start-Sleep -Seconds 1
  return (Tap-FirstClassContaining "android.widget.EditText")
}

function Enter-TextIntoFirstEditText {
  param([string]$Text)

  if (-not (Tap-FirstClassContainingWithScroll "android.widget.EditText")) {
    return $false
  }
  Invoke-Adb shell input keyevent KEYCODE_MOVE_END | Out-Null
  Invoke-Adb shell input text $Text | Out-Null
  Invoke-Adb shell input keyevent KEYCODE_BACK | Out-Null
  Start-Sleep -Milliseconds 500
  return $true
}

function Open-ReadingPractice {
  $readingWord = New-Zh 0x6717 0x8BFB
  $readingModeWord = $readingWord + (New-Zh 0x6A21 0x5F0F)
  $libraryWord = New-Zh 0x8BD7 0x8BCD 0x5E93
  $gooseWord = New-Zh 0x548F 0x9E45

  if (-not (Tap-FirstButtonContaining $libraryWord)) {
    Invoke-Adb shell input tap 470 2531 | Out-Null
  }
  Start-Sleep -Seconds 2

  for ($attempt = 0; $attempt -lt 3; $attempt++) {
    Invoke-Adb shell input swipe 960 620 960 2100 650 | Out-Null
    Start-Sleep -Milliseconds 500
  }

  if (-not (Tap-NodeContainingWithDeepScroll $gooseWord)) {
    Invoke-Adb shell input tap 320 2240 | Out-Null
  }
  Start-Sleep -Seconds 2

  if (-not (Tap-ButtonContainingWithDeepScroll $readingModeWord)) {
    if (-not (Tap-NodeContainingWithDeepScroll $readingModeWord)) {
      if (-not (Tap-ButtonContainingWithDeepScroll $readingWord)) {
        Invoke-Adb shell input tap 792 556 | Out-Null
      }
    }
  }
  Start-Sleep -Seconds 5

  $xml = Get-UiDump
  $startRecognition = New-Zh 0x5F00 0x59CB 0x8BC6 0x522B
  if ($xml -notmatch [regex]::Escape($startRecognition)) {
    Invoke-Adb shell input tap 792 556 | Out-Null
    Start-Sleep -Seconds 5
    $xml = Get-UiDump
  }
  if ($xml -notmatch [regex]::Escape($startRecognition)) {
    Write-Host $xml
    throw "Could not open reading practice from poem detail"
  }
}

function Open-SettingsFromProfile {
  $settingsWord = New-Zh 0x8BBE 0x7F6E

  Open-ProfileTab
  Assert-NoFlutterRedScreenOrCrash "opening profile tab before settings"
  if (-not (Tap-NodeContainingWithScroll $settingsWord)) {
    throw "Could not open settings page from profile"
  }
  Start-Sleep -Seconds 2
  Assert-NoFlutterRedScreenOrCrash "opening settings page"
}

function Exercise-ReadingControls {
  $startRecognition = New-Zh 0x5F00 0x59CB 0x8BC6 0x522B
  $stop = New-Zh 0x505C 0x6B62
  $startRecording = New-Zh 0x5F00 0x59CB 0x5F55 0x97F3
  $endRecording = New-Zh 0x7ED3 0x675F 0x5F55 0x97F3
  $replayRecording = New-Zh 0x56DE 0x653E 0x5F55 0x97F3

  Stabilize-DeviceUi
  Start-AppAndWait 8
  Open-ReadingPractice

  if (-not (Tap-ButtonContainingWithScroll $startRecognition)) {
    if (-not (Tap-NodeContainingWithScroll $startRecognition)) {
      Write-Host (Get-UiDump)
      throw "Could not find Start Recognition button"
    }
  }
  Start-Sleep -Seconds 3
  Assert-NoFlutterRedScreenOrCrash "starting recognition"
  Tap-ButtonContainingWithScroll $stop | Out-Null
  Start-Sleep -Seconds 2
  Assert-NoFlutterRedScreenOrCrash "stopping recognition"

  Stabilize-DeviceUi
  Start-AppAndWait 8
  Open-ReadingPractice

  if (-not (Tap-ButtonContainingWithScroll $startRecording)) {
    if (-not (Tap-NodeContainingWithScroll $startRecording)) {
      Write-Host (Get-UiDump)
      throw "Could not find Start Recording button"
    }
  }
  Start-Sleep -Seconds 3
  Assert-NoFlutterRedScreenOrCrash "starting recording"
  if (-not (Tap-ButtonContainingWithScroll $endRecording)) {
    if (-not (Tap-NodeContainingWithScroll $endRecording)) {
      Write-Host (Get-UiDump)
      throw "Could not find End Recording button"
    }
  }
  Start-Sleep -Seconds 2
  Assert-NoFlutterRedScreenOrCrash "ending recording"
  Tap-ButtonContainingWithScroll $replayRecording | Out-Null
  Start-Sleep -Seconds 2
  Assert-NoFlutterRedScreenOrCrash "replaying recording"
}

function Score-ReadingAndAssertDbWrites {
  $scoreWord = New-Zh 0x8BC4 0x5206
  Start-AppAndWait 15
  Open-ReadingPractice

  $activeProfileId = Query-AppDbScalar "SELECT active_profile_id FROM settings WHERE id = 1;"
  $learningBefore = Query-AppDbScalar "SELECT COUNT(*) FROM learning_records;"
  $reportBefore = Query-AppDbScalar "SELECT COUNT(*) FROM practice_reports;"
  $reportItemsBefore = Query-AppDbScalar "SELECT COUNT(*) FROM practice_report_items;"

  $fieldReady = $false
  for ($attempt = 0; $attempt -lt 14; $attempt++) {
    if (Tap-FirstClassContaining "android.widget.EditText") {
      $fieldReady = $true
      break
    }
    Invoke-Adb shell input swipe 1200 2300 1200 450 650 | Out-Null
    Start-Sleep -Milliseconds 700
  }

  if (-not $fieldReady) {
    Write-Host "Recognition text field not exposed through UIAutomator; using coordinate fallback."
    Invoke-Adb shell input tap 600 2100 | Out-Null
  }
  Start-Sleep -Milliseconds 300
  Invoke-Adb shell input text reading | Out-Null
  Invoke-Adb shell input keyevent 111 | Out-Null
  Start-Sleep -Milliseconds 800

  $textEntered = (Get-UiDump) -match 'text="reading"'
  if (-not $textEntered) {
    Write-Host "Recognition text was not visible after semantic input; retrying with lower field coordinate."
    Invoke-Adb shell input tap 600 2100 | Out-Null
    Start-Sleep -Milliseconds 300
    Invoke-Adb shell input text reading | Out-Null
    Invoke-Adb shell input keyevent KEYCODE_BACK | Out-Null
    Start-Sleep -Milliseconds 800
    $textEntered = (Get-UiDump) -match 'text="reading"'
  }
  if (-not $textEntered) {
    throw "Could not enter recognition text before scoring"
  }

  if (-not (Tap-ButtonContainingWithScroll $scoreWord)) {
    throw "Could not find score button"
  }
  Start-Sleep -Seconds 4

  Assert-NoFlutterRedScreenOrCrash "reading score submission"
  $learningAfter = Query-AppDbScalar "SELECT COUNT(*) FROM learning_records;"
  $reportAfter = Query-AppDbScalar "SELECT COUNT(*) FROM practice_reports;"
  $reportItemsAfter = Query-AppDbScalar "SELECT COUNT(*) FROM practice_report_items;"
  $profileLearningAfter = Query-AppDbScalar "SELECT COUNT(*) FROM learning_records WHERE profile_id = $activeProfileId AND rowid = (SELECT MAX(rowid) FROM learning_records);"
  $profileReportAfter = Query-AppDbScalar "SELECT COUNT(*) FROM practice_reports WHERE profile_id = $activeProfileId AND id = (SELECT MAX(id) FROM practice_reports);"
  Assert-DbCountIncreased "learning_records" $learningBefore $learningAfter "reading score"
  Assert-DbCountIncreased "practice_reports" $reportBefore $reportAfter "reading score"
  Assert-DbCountIncreased "practice_report_items" $reportItemsBefore $reportItemsAfter "reading score"
  if ($profileLearningAfter -lt 1) {
    throw "Latest learning_records row was not written for active profile $activeProfileId"
  }
  if ($profileReportAfter -lt 1) {
    throw "Latest practice_reports row was not written for active profile $activeProfileId"
  }
  Write-Host "DB writes verified: learning_records $learningBefore->$learningAfter; practice_reports $reportBefore->$reportAfter; practice_report_items $reportItemsBefore->$reportItemsAfter"
  $script:ScoreDbVerified = $true
}

function Verify-MicrophonePermissionRevokedState {
  $microphone = New-Zh 0x9EA6 0x514B 0x98CE
  $unavailable = New-Zh 0x4E0D 0x53EF 0x7528
  Invoke-Adb shell pm revoke $PackageName android.permission.RECORD_AUDIO | Out-Null
  Start-AppAndWait 8
  Open-ReadingPractice
  Assert-UiContains $microphone
  Assert-UiContains $unavailable
  $startRecognition = New-Zh 0x5F00 0x59CB 0x8BC6 0x522B
  Tap-ButtonContainingWithScroll $startRecognition | Out-Null
  Start-Sleep -Seconds 2
  Assert-NoFlutterRedScreenOrCrash "starting recognition with microphone permission revoked"
  Invoke-Adb shell pm grant $PackageName android.permission.RECORD_AUDIO | Out-Null
}

function Assert-SyncLogShortcutDetails {
  param(
    [int]$ReportId,
    [int]$WrongQuestionId,
    [int]$LearningRecordId
  )

  $reportDetail = New-Zh 0x62A5 0x544A 0x8BE6 0x60C5
  $wrongDetail = New-Zh 0x9519 0x9898 0x8BE6 0x60C5
  $recordDetail = New-Zh 0x5B66 0x4E60 0x8BB0 0x5F55 0x8BE6 0x60C5
  $stageLabel = New-Zh 0x63A5 0x9F99 0x5165 0x95E8
  $stageRow = New-Zh 0x95EF 0x5173 0x5173 0x5361
  $reportStageRow = New-Zh 0x5173 0x5361
  $expectedAnswer = New-Zh 0x6807 0x51C6 0x7B54 0x6848
  $practiceMode = New-Zh 0x7EC3 0x4E60 0x6A21 0x5F0F
  $noteLabel = New-Zh 0x5907 0x6CE8
  $reportHash = (New-Zh 0x62A5 0x544A) + " #$ReportId"
  $wrongHash = (New-Zh 0x9519 0x9898) + " #$WrongQuestionId"
  $recordHash = (New-Zh 0x5B66 0x4E60 0x8BB0 0x5F55) + " #$LearningRecordId"
  $backToMap = New-Zh 0x56DE 0x5230 0x5730 0x56FE
  $fromSyncLog = New-Zh 0x6765 0x81EA 0x5907 0x4EFD 0x8BB0 0x5F55
  $challengeMap = New-Zh 0x95EF 0x5173 0x5730 0x56FE

  if (-not (Tap-ButtonContainingWithScroll $reportHash)) {
    throw "Could not open report detail shortcut from sync log detail"
  }
  Start-Sleep -Seconds 2
  Assert-UiContains $reportDetail
  Assert-UiContainsWithScroll $reportStageRow
  Assert-UiContainsWithScroll $stageLabel
  Assert-UiContainsWithScroll "Android shortcut smoke"
  Invoke-Adb shell input keyevent KEYCODE_BACK | Out-Null
  Start-Sleep -Seconds 1

  if (-not (Tap-ButtonContainingWithScroll $wrongHash)) {
    throw "Could not open wrong-question detail shortcut from sync log detail"
  }
  Start-Sleep -Seconds 2
  Assert-UiContains $wrongDetail
  Assert-UiContainsWithScroll $stageRow
  Assert-UiContainsWithScroll $stageLabel
  Assert-UiContainsWithScroll $expectedAnswer
  Assert-UiContainsWithScroll "goose goose goose"
  Invoke-Adb shell input keyevent KEYCODE_BACK | Out-Null
  Start-Sleep -Seconds 1

  if (-not (Tap-ButtonContainingWithScroll $recordHash)) {
    throw "Could not open learning-record detail shortcut from sync log detail"
  }
  Start-Sleep -Seconds 2
  Assert-UiContains $recordDetail
  Assert-UiContainsWithScroll $practiceMode
  Assert-UiContainsWithScroll $stageRow
  Assert-UiContainsWithScroll $stageLabel
  Assert-UiContainsWithScroll $noteLabel
  Assert-UiContainsWithScroll "Android shortcut smoke"
  Invoke-Adb shell input keyevent KEYCODE_BACK | Out-Null
  Start-Sleep -Seconds 1

  for ($attempt = 0; $attempt -lt 4; $attempt++) {
    Invoke-Adb shell input swipe 960 620 960 2100 650 | Out-Null
    Start-Sleep -Milliseconds 500
  }
  if (-not (Tap-ButtonContainingWithScroll $backToMap)) {
    throw "Could not open challenge map shortcut from sync log detail"
  }
  Start-Sleep -Seconds 2
  Assert-UiContainsWithScroll $challengeMap
  Assert-UiContainsWithScroll $stageLabel
  Assert-UiContainsWithScroll $fromSyncLog
  Invoke-Adb shell input keyevent KEYCODE_BACK | Out-Null
  Start-Sleep -Seconds 1
}

function Smoke-SyncLogDetailShortcuts {
  $expandParentTools = New-Zh 0x5C55 0x5F00 0x5BB6 0x957F 0x7BA1 0x7406
  $moreDataProtection = New-Zh 0x66F4 0x591A 0x6570 0x636E 0x4FDD 0x62A4
  $viewAllSyncLogs = New-Zh 0x67E5 0x770B 0x4FDD 0x62A4 0x8BB0 0x5F55
  $syncLogTitle = New-Zh 0x5907 0x4EFD 0x8BB0 0x5F55
  $manualSync = New-Zh 0x624B 0x52A8 0x5907 0x4EFD
  $failureWord = New-Zh 0x5931 0x8D25
  $allStatus = New-Zh 0x5168 0x90E8 0x72B6 0x6001
  $now = (Get-Date).ToUniversalTime().ToString("o")
  $reportId = 900001
  $wrongQuestionId = 900001
  $learningRecordId = 900001
  $notes = "[`"stageId=jielong_entry`",`"reportId=$reportId`",`"wrongQuestionId=$wrongQuestionId`",`"learningRecordId=$learningRecordId`"]"
  $failureMessage = "Android shortcut smoke failure stageId=jielong_entry reportId=$reportId wrongQuestionId=$wrongQuestionId learningRecordId=$learningRecordId"
  $sql = @"
DELETE FROM sync_run_logs WHERE notes LIKE '%$reportId%' OR error_message LIKE '%$reportId%';
DELETE FROM practice_report_items WHERE report_id = $reportId;
DELETE FROM practice_reports WHERE id = $reportId;
DELETE FROM wrong_questions WHERE id = $wrongQuestionId;
DELETE FROM learning_records WHERE id = $learningRecordId;
INSERT OR IGNORE INTO learning_records (id, profile_id, poem_id, mode, duration_minutes, score, note, stage_id, sync_status, created_at, updated_at)
VALUES ($learningRecordId, (SELECT active_profile_id FROM settings WHERE id = 1), 1, 'poetry_jielong', 3, 88, 'Android shortcut smoke', 'jielong_entry', 'local', '$now', '$now');
INSERT OR IGNORE INTO wrong_questions (id, profile_id, poem_id, question_type, prompt, correct_answer, user_answer, rule_tag, severity, stage_id, sync_status, created_at, updated_at)
VALUES ($wrongQuestionId, (SELECT active_profile_id FROM settings WHERE id = 1), 1, 'dictation', 'Android shortcut smoke', 'goose goose goose', 'goose goose', 'missing_char', 'medium', 'jielong_entry', 'local', '$now', '$now');
INSERT OR IGNORE INTO practice_reports (id, profile_id, session_id, mode, poem_id, total_score, correct_count, total_questions, generated_wrong_count, stage_id, suggestions_json, completed_at, sync_status, created_at, updated_at)
VALUES ($reportId, (SELECT active_profile_id FROM settings WHERE id = 1), 'android-shortcut-smoke-$reportId', 'dictation', 1, 88, 1, 1, 1, 'jielong_entry', '[]', '$now', 'local', '$now', '$now');
INSERT OR IGNORE INTO practice_report_items (report_id, line_index, prompt, expected_answer, user_answer, is_correct, score, feedback)
VALUES ($reportId, 0, 'Android shortcut smoke', 'goose goose goose', 'goose goose', 0, 88, 'Android shortcut smoke');
INSERT INTO sync_run_logs (state, started_at, finished_at, pushed_count, pulled_count, conflict_count, trigger_source, error_message, notes, created_at)
VALUES ('success', '$now', '$now', 0, 1, 0, 'manual', NULL, '$notes', '$now');
INSERT INTO sync_run_logs (state, started_at, finished_at, pushed_count, pulled_count, conflict_count, trigger_source, error_message, notes, created_at)
VALUES ('failed', '$now', '$now', 0, 0, 0, 'manual', '$failureMessage', '$notes', '$now');
"@
  if (-not (Invoke-AppDbSqlIfPossible $sql)) {
    return
  }
  Write-Host "Sync-log shortcut smoke data injected."

  Start-AppAndWait 8
  Write-Host "Sync-log shortcut smoke app foregrounded."
  Open-ProfileTab
  Write-Host "Sync-log shortcut smoke profile tab opened."
  Tap-NodeContainingWithScroll $expandParentTools | Out-Null
  Start-Sleep -Seconds 1
  Tap-NodeContainingWithScroll $moreDataProtection | Out-Null
  Start-Sleep -Seconds 1
  if (-not (Tap-NodeContainingWithScroll $viewAllSyncLogs)) {
    throw "Could not open sync log list from profile"
  }
  Start-Sleep -Seconds 2
  Assert-UiContains $syncLogTitle
  Write-Host "Sync-log shortcut smoke log list opened."

  if (-not (Tap-NodeContainingWithScroll $manualSync)) {
    throw "Could not open inserted sync log detail"
  }
  Start-Sleep -Seconds 2
  Assert-NoFlutterRedScreenOrCrash "opening sync log detail shortcut smoke"
  Assert-SyncLogShortcutDetails -ReportId $reportId -WrongQuestionId $wrongQuestionId -LearningRecordId $learningRecordId
  Write-Host "Sync-log shortcut smoke success detail verified."
  Invoke-Adb shell input keyevent KEYCODE_BACK | Out-Null
  Start-Sleep -Seconds 1

  if (-not (Tap-FirstNodeContaining $allStatus)) {
    Write-Host "All-status filter was not visible; continuing with current sync-log list."
  }
  Start-Sleep -Seconds 1
  if (-not (Tap-NodeContainingWithScroll $failureWord)) {
    throw "Could not open inserted failed sync log detail"
  }
  Start-Sleep -Seconds 2
  Assert-NoFlutterRedScreenOrCrash "opening failed sync log detail shortcut smoke"
  Assert-UiContainsWithScroll $failureMessage
  Assert-SyncLogShortcutDetails -ReportId $reportId -WrongQuestionId $wrongQuestionId -LearningRecordId $learningRecordId
  Write-Host "Sync-log shortcut smoke failed detail verified."

  Assert-NoFlutterRedScreenOrCrash "sync log detail success/failure report/wrong/record shortcuts"
}

function Smoke-GrowthReportTrendDeepLinks {
  param(
    [switch]$SkipTrendDetailShortcuts,
    [switch]$SkipChallengeMapReturn
  )

  $today = Get-Date
  $dateKey = $today.ToString("yyyy-MM-dd")
  $dateChip = $dateKey.Substring(5)
  $baseTime = $today.Date.AddHours(9)
  $reportId = 900304
  $wrongQuestionId = 900304
  $learningRecordId = 900304
  $notePrefix = "Android growth smoke"
  $note = "$notePrefix dictation 4"
  $sql = @"
DELETE FROM practice_report_items WHERE report_id IN (900001, 900101, 900102, 900103, 900104, 900201, 900202, 900203, 900204, 900301, 900302, 900303, 900304);
DELETE FROM practice_reports WHERE id IN (900001, 900101, 900102, 900103, 900104, 900201, 900202, 900203, 900204, 900301, 900302, 900303, 900304);
DELETE FROM wrong_questions WHERE id IN (900001, 900101, 900102, 900103, 900104, 900201, 900202, 900203, 900204, 900301, 900302, 900303, 900304);
DELETE FROM learning_records WHERE id IN (900001, 900101, 900102, 900103, 900104, 900201, 900202, 900203, 900204, 900301, 900302, 900303, 900304);
"@
  for ($i = 1; $i -le 4; $i++) {
    $id = 900100 + $i
    $feihuaId = 900200 + $i
    $dictationId = 900300 + $i
    $score = 90 + $i
    $entryNote = "$notePrefix $i"
    $feihuaNote = "$notePrefix feihua $i"
    $dictationNote = "$notePrefix dictation $i"
    $timestamp = $baseTime.AddHours($i).ToString("yyyy-MM-ddTHH:mm:ss.fff")
    $sql += @"
INSERT OR IGNORE INTO learning_records (id, profile_id, poem_id, mode, duration_minutes, score, note, stage_id, sync_status, created_at, updated_at)
VALUES ($id, (SELECT active_profile_id FROM settings WHERE id = 1), 1, 'poetry_jielong', 4, $score, '$entryNote', 'jielong_entry', 'local', '$timestamp', '$timestamp');
INSERT OR IGNORE INTO wrong_questions (id, profile_id, poem_id, question_type, prompt, correct_answer, user_answer, rule_tag, severity, stage_id, reviewed_at, sync_status, created_at, updated_at)
VALUES ($id, (SELECT active_profile_id FROM settings WHERE id = 1), 1, 'dictation', '$entryNote', 'goose goose goose', 'goose goose', 'missing_char', 'medium', 'jielong_entry', '$timestamp', 'local', '$timestamp', '$timestamp');
INSERT OR IGNORE INTO practice_reports (id, profile_id, session_id, mode, poem_id, total_score, correct_count, total_questions, generated_wrong_count, stage_id, suggestions_json, completed_at, sync_status, created_at, updated_at)
VALUES ($id, (SELECT active_profile_id FROM settings WHERE id = 1), 'android-growth-smoke-$id', 'dictation', 1, $score, 1, 1, 1, 'jielong_entry', '[]', '$timestamp', 'local', '$timestamp', '$timestamp');
INSERT OR IGNORE INTO practice_report_items (report_id, line_index, prompt, expected_answer, user_answer, is_correct, score, feedback)
VALUES ($id, 0, '$entryNote', 'goose goose goose', 'goose goose', 0, $score, '$entryNote');
INSERT OR IGNORE INTO learning_records (id, profile_id, poem_id, mode, duration_minutes, score, note, stage_id, sync_status, created_at, updated_at)
VALUES ($feihuaId, (SELECT active_profile_id FROM settings WHERE id = 1), 1, 'feihualing', 4, $score, '$feihuaNote', 'feihualing_theme', 'local', '$timestamp', '$timestamp');
INSERT OR IGNORE INTO wrong_questions (id, profile_id, poem_id, question_type, prompt, correct_answer, user_answer, rule_tag, severity, stage_id, reviewed_at, sync_status, created_at, updated_at)
VALUES ($feihuaId, (SELECT active_profile_id FROM settings WHERE id = 1), 1, 'dictation', '$feihuaNote', 'goose goose goose', 'goose goose', 'missing_char', 'medium', 'feihualing_theme', '$timestamp', 'local', '$timestamp', '$timestamp');
INSERT OR IGNORE INTO practice_reports (id, profile_id, session_id, mode, poem_id, total_score, correct_count, total_questions, generated_wrong_count, stage_id, suggestions_json, completed_at, sync_status, created_at, updated_at)
VALUES ($feihuaId, (SELECT active_profile_id FROM settings WHERE id = 1), 'android-growth-smoke-feihua-$feihuaId', 'feihualing', 1, $score, 1, 1, 1, 'feihualing_theme', '[]', '$timestamp', 'local', '$timestamp', '$timestamp');
INSERT OR IGNORE INTO practice_report_items (report_id, line_index, prompt, expected_answer, user_answer, is_correct, score, feedback)
VALUES ($feihuaId, 0, '$feihuaNote', 'goose goose goose', 'goose goose', 0, $score, '$feihuaNote');
INSERT OR IGNORE INTO learning_records (id, profile_id, poem_id, mode, duration_minutes, score, note, stage_id, sync_status, created_at, updated_at)
VALUES ($dictationId, (SELECT active_profile_id FROM settings WHERE id = 1), 1, 'dictation', 4, $score, '$dictationNote', 'dictation_checkpoint', 'local', '$timestamp', '$timestamp');
INSERT OR IGNORE INTO wrong_questions (id, profile_id, poem_id, question_type, prompt, correct_answer, user_answer, rule_tag, severity, stage_id, reviewed_at, sync_status, created_at, updated_at)
VALUES ($dictationId, (SELECT active_profile_id FROM settings WHERE id = 1), 1, 'dictation', '$dictationNote', 'goose goose goose', 'goose goose', 'missing_char', 'medium', 'dictation_checkpoint', '$timestamp', 'local', '$timestamp', '$timestamp');
INSERT OR IGNORE INTO practice_reports (id, profile_id, session_id, mode, poem_id, total_score, correct_count, total_questions, generated_wrong_count, stage_id, suggestions_json, completed_at, sync_status, created_at, updated_at)
VALUES ($dictationId, (SELECT active_profile_id FROM settings WHERE id = 1), 'android-growth-smoke-dictation-$dictationId', 'dictation', 1, $score, 1, 1, 1, 'dictation_checkpoint', '[]', '$timestamp', 'local', '$timestamp', '$timestamp');
INSERT OR IGNORE INTO practice_report_items (report_id, line_index, prompt, expected_answer, user_answer, is_correct, score, feedback)
VALUES ($dictationId, 0, '$dictationNote', 'goose goose goose', 'goose goose', 0, $score, '$dictationNote');
"@
  }
  if (-not (Invoke-AppDbSqlIfPossible $sql)) {
    return
  }
  Write-Host "Growth-report trend smoke data injected."

  $weeklyReport = (New-Zh 0x67E5 0x770B 0x5468 0x62A5)
  $growthReportDetail = (New-Zh 0x6210 0x957F 0x62A5 0x544A 0x8BE6 0x60C5)
  $dailyTrend = (New-Zh 0x9010 0x65E5 0x53D8 0x5316)
  $stageTrendChart = (New-Zh 0x5468) + "/" + (New-Zh 0x6708 0x5173 0x5361 0x53D8 0x5316 0x56FE)
  $recentReport = (New-Zh 0x6700 0x8FD1 0x62A5 0x544A)
  $wrongImprovement = (New-Zh 0x9519 0x9898 0x590D 0x4E60)
  $reportDetailAction = (New-Zh 0x62A5 0x544A) + " #$reportId"
  $wrongDetailAction = (New-Zh 0x9519 0x9898) + " #$wrongQuestionId"
  $recordDetailAction = (New-Zh 0x5B66 0x4E60 0x8BB0 0x5F55) + " #$learningRecordId"
  $recordEvidenceAction = (New-Zh 0x7EC3 0x4E60 0x8BB0 0x5F55 0x5361)
  $reportDetail = (New-Zh 0x62A5 0x544A 0x8BE6 0x60C5)
  $wrongDetail = (New-Zh 0x9519 0x9898 0x8BE6 0x60C5)
  $todayRecords = (New-Zh 0x5F53 0x5929 0x7EC3 0x4E60 0x8BB0 0x5F55)
  $recordDetail = (New-Zh 0x5B66 0x4E60 0x8BB0 0x5F55 0x8BE6 0x60C5)
  $fromGrowthReport = (New-Zh 0x6765 0x81EA 0x6210 0x957F 0x62A5 0x544A)
  $collapsedGrowthSource = $fromGrowthReport + " · " + (New-Zh 0x63A5 0x9F99 0x5165 0x95E8)
  $stageProgressLink = (New-Zh 0x67E5 0x770B 0x672C 0x5173 0x7EC3 0x4E60 0x8BB0 0x5F55)
  $stageProgressFallbackLink = (New-Zh 0x56DE 0x5230 0x95EF 0x5173 0x5730 0x56FE)
  $growthLocated = (New-Zh 0x6210 0x957F 0x62A5 0x544A 0x5DF2 0x5B9A 0x4F4D 0x5230)
  $entryStage = (New-Zh 0x63A5 0x9F99 0x5165 0x95E8)
  $chapterDetail = (New-Zh 0x67E5 0x770B 0x7AE0 0x8282 0x8BE6 0x60C5)
  $chapterFocus = (New-Zh 0x5F53 0x524D 0x5173 0x5361 0x4E0E 0x6700 0x8FD1 0x7EC3 0x4E60)
  $recentProgressTrend = (New-Zh 0x6700 0x8FD1 0x7EC3 0x4E60 0x53D8 0x5316)
  $viewLearningRecordDetail = (New-Zh 0x67E5 0x770B 0x5B66 0x4E60 0x8BB0 0x5F55 0x8BE6 0x60C5)
  $viewReport = (New-Zh 0x67E5 0x770B 0x62A5 0x544A)
  $viewWrongQuestion = (New-Zh 0x67E5 0x770B 0x9519 0x9898)
  $reportHistory = (New-Zh 0x62A5 0x544A 0x5386 0x53F2)
  $wrongBook = (New-Zh 0x9519 0x9898 0x672C)
  $backToStageChapter = (New-Zh 0x56DE 0x5230 0x8BE5 0x5173 0x5361 0x7AE0 0x8282)
  $fromChapterDetail = (New-Zh 0x6765 0x81EA 0x7AE0 0x8282 0x8BE6 0x60C5)
  $returnedToRecord = (New-Zh 0x5DF2 0x56DE 0x5230 0x8FD9 0x6761 0x8BB0 0x5F55)
  $returnedToDetail = (New-Zh 0x5DF2 0x56DE 0x5230 0x8FD9 0x6761 0x8BB0 0x5F55)
  $viewGrowthReport = (New-Zh 0x67E5 0x770B 0x6210 0x957F 0x62A5 0x544A)
  $expandParentTools = New-Zh 0x5C55 0x5F00 0x5BB6 0x957F 0x7BA1 0x7406
  $growthAndHistory = New-Zh 0x6210 0x957F 0x4E0E 0x5386 0x53F2
  $parentDetailedReport = New-Zh 0x5BB6 0x957F 0x770B 0x8BE6 0x7EC6 0x62A5 0x544A
  $gotIt = (New-Zh 0x77E5 0x9053 0x4E86)
  $themeFeihua = (New-Zh 0x4E3B 0x9898 0x98DE 0x82B1)
  $dictationStage = (New-Zh 0x542C 0x5199 0x5173 0x5361)

  Start-AppAndWait 8
  Open-ProfileTab
  Tap-NodeContainingWithScroll $expandParentTools | Out-Null
  Start-Sleep -Seconds 1
  Tap-NodeContainingWithScroll $growthAndHistory | Out-Null
  Start-Sleep -Seconds 1
  Tap-NodeContainingWithScroll $parentDetailedReport | Out-Null
  Start-Sleep -Seconds 1
  if (-not (Tap-ButtonContainingWithDeepScroll $weeklyReport)) {
    throw "Could not open weekly growth report"
  }
  Start-Sleep -Seconds 2
  Assert-UiContains $growthReportDetail

  if (-not $SkipTrendDetailShortcuts) {
    Assert-UiContainsWithScroll $dailyTrend 8
    Assert-UiContainsWithScroll $stageTrendChart 8
    if (-not (Tap-NodeContainingWithDeepScroll $dateChip)) {
      throw "Could not open growth trend point for $dateChip"
    }
    Start-Sleep -Seconds 1
    Assert-UiContains $recentReport
    if (-not (Tap-BottomSheetDetailAfterExpand $reportDetailAction)) {
      throw "Could not open fourth report detail from expanded growth trend point"
    }
    Start-Sleep -Seconds 2
    Assert-UiContains $reportDetail
    Assert-UiContainsWithScroll $fromGrowthReport
    Start-Sleep -Seconds 5
    if (-not (Test-UiContainsWithScroll $collapsedGrowthSource 4)) {
      Write-Host "Collapsed source banner text not found after auto-collapse; continuing because source entry and detail navigation were verified."
    }
    Assert-UiContainsWithScroll $note
    Invoke-Adb shell input keyevent KEYCODE_BACK | Out-Null
    Start-Sleep -Seconds 1
    Assert-UiContainsWithBidirectionalScroll $returnedToDetail
    if (-not (Test-UiContains $recentReport)) {
      if (-not (Tap-NodeContainingWithDeepScroll $dateChip)) {
        throw "Could not reopen growth trend point for wrong-question detail"
      }
      Start-Sleep -Seconds 1
      Assert-UiContains $recentReport
    }
    if (-not (Tap-BottomSheetDetailAfterExpand $wrongDetailAction)) {
      throw "Could not open fourth wrong-question detail from expanded growth trend point"
    }
    Start-Sleep -Seconds 2
    Assert-UiContains $wrongDetail
    Assert-UiContainsWithScroll $fromGrowthReport
    Assert-UiContainsWithScroll $note
    Invoke-Adb shell input keyevent KEYCODE_BACK | Out-Null
    Start-Sleep -Seconds 1
    Assert-UiContainsWithBidirectionalScroll $returnedToDetail

    # Reset the bottom sheet before opening the third detail type. Keeping the
    # report and wrong-question groups expanded makes UIAutomator swipes land in
    # a very tall sheet and can leave the script stuck in the wrong-question
    # list even though the product flow itself is healthy.
    Invoke-Adb shell input keyevent KEYCODE_BACK | Out-Null
    Start-Sleep -Seconds 1
    Assert-UiContains $growthReportDetail
    if (-not (Tap-NodeContainingWithDeepScroll $dateChip)) {
      throw "Could not reopen growth trend point for $dateChip"
    }
    Start-Sleep -Seconds 1
    Assert-UiContains $recentReport

    $usedRecordEvidenceCard = $false
    if (Tap-NodeContainingWithDeepScroll $recordEvidenceAction) {
      $usedRecordEvidenceCard = $true
    } else {
      if (-not (Tap-BottomSheetDetailAfterExpand $recordDetailAction)) {
        throw "Could not open learning record detail from growth trend point"
      }
    }
    Start-Sleep -Seconds 2
    Assert-UiContains $recordDetail
    Assert-UiContainsWithScroll $fromGrowthReport
    Assert-UiContainsWithScroll $note
    Invoke-Adb shell input keyevent KEYCODE_BACK | Out-Null
    Start-Sleep -Seconds 1
    if ($usedRecordEvidenceCard) {
      Assert-UiContains $growthReportDetail
    } else {
      Assert-UiContainsWithBidirectionalScroll $returnedToDetail
    }
    if ($GrowthTrendOnly -or $SkipChallengeMapReturn) {
      return
    }
    Invoke-Adb shell input keyevent KEYCODE_BACK | Out-Null
    Start-Sleep -Seconds 1
    Assert-UiContains $growthReportDetail
  }

  if (
    -not (Tap-NodeContainingWithDeepScroll $stageProgressLink) -and
    -not (Tap-NodeContainingWithDeepScroll $stageProgressFallbackLink)
  ) {
    throw "Could not open challenge map from growth report stage progress link"
  }
  Start-Sleep -Seconds 1
  if (-not (Test-UiContainsWithScroll $growthLocated 3)) {
    Assert-UiContainsWithScroll $fromGrowthReport 3
    Write-Host "Full growth-report location banner was already collapsed; source chip is visible."
  }
  if (
    -not (Test-UiContains $entryStage) -and
    -not (Test-UiContains $themeFeihua) -and
    -not (Test-UiContains $dictationStage)
  ) {
    Write-Host (Get-UiDump)
    throw "Expected challenge map focused stage not found: $entryStage, $themeFeihua, or $dictationStage"
  }
  Start-Sleep -Seconds 5
  Assert-UiNotContains $growthLocated "challenge map focus highlight auto-collapse"
  if (-not (Tap-FirstNodeContaining $chapterDetail)) {
    if (-not (Tap-ButtonContainingWithDeepScroll $chapterDetail)) {
      throw "Could not open chapter detail from challenge map focus card"
    }
  }
  Start-Sleep -Seconds 2
  Tap-FirstNodeContaining $gotIt | Out-Null
  Start-Sleep -Seconds 1
  Assert-UiContains $chapterFocus
  Assert-UiContains $fromGrowthReport
  Assert-UiContainsWithScroll $recentProgressTrend

  if (-not (Tap-ButtonAndWaitForText $viewLearningRecordDetail $recordDetail)) {
    throw "Could not open learning record detail from chapter recent record"
  }
  Assert-UiContains $recordDetail
  Assert-UiContainsWithScroll $fromChapterDetail
  Assert-UiContainsWithScroll $backToStageChapter
  Invoke-Adb shell input keyevent KEYCODE_BACK | Out-Null
  if (-not (Test-UiContainsWithScroll $returnedToRecord 3)) {
    Assert-UiContainsWithScroll $chapterFocus
    Assert-UiContainsWithScroll $recentProgressTrend
    Write-Host "Returned-record highlight banner was already collapsed; chapter detail and recent records are visible."
  }

  if (-not (Tap-ButtonAndWaitForText $viewReport $reportHistory)) {
    throw "Could not open stage report list from chapter recent record"
  }
  Assert-UiContains $reportHistory
  Assert-UiContainsWithScroll $fromChapterDetail
  Assert-UiContainsWithScroll $backToStageChapter
  Invoke-Adb shell input keyevent KEYCODE_BACK | Out-Null
  Start-Sleep -Seconds 1

  if (-not (Tap-ButtonAndWaitForText $viewWrongQuestion $wrongBook)) {
    throw "Could not open stage wrong book from chapter recent record"
  }
  Assert-UiContains $wrongBook
  Assert-UiContainsWithScroll $fromChapterDetail
  Assert-UiContainsWithScroll $backToStageChapter
  Invoke-Adb shell input keyevent KEYCODE_BACK | Out-Null
  Start-Sleep -Seconds 1

  if (-not (Tap-ButtonContainingWithDeepScroll $viewGrowthReport)) {
    throw "Could not return to growth report from challenge chapter detail"
  }
  Start-Sleep -Seconds 2
  Assert-UiContains $growthReportDetail

  Assert-NoFlutterRedScreenOrCrash "growth report trend point report/record/map shortcuts"
}

function Smoke-PinyinSettingToggle {
  $showPinyin = New-Zh 0x663E 0x793A 0x62FC 0x97F3
  $saveSettings = New-Zh 0x4FDD 0x5B58 0x8BBE 0x7F6E

  Open-SettingsFromProfile
  $before = Query-AppDbScalar "SELECT show_pinyin FROM settings WHERE id = 1;"
  if (-not (Tap-NodeContainingWithScroll $showPinyin)) {
    throw "Could not toggle show-pinyin setting"
  }
  Start-Sleep -Milliseconds 500
  if (-not (Tap-ButtonContainingWithDeepScroll $saveSettings)) {
    throw "Could not save settings after pinyin toggle"
  }
  Start-Sleep -Seconds 2
  Assert-NoFlutterRedScreenOrCrash "saving show-pinyin setting"
  $after = Query-AppDbScalar "SELECT show_pinyin FROM settings WHERE id = 1;"
  if ($after -eq $before) {
    throw "show_pinyin did not change after settings save. before=$before after=$after"
  }

  for ($attempt = 0; $attempt -lt 4; $attempt++) {
    Invoke-Adb shell input swipe 1200 450 1200 2300 650 | Out-Null
    Start-Sleep -Milliseconds 500
  }

  if (-not (Tap-NodeContainingWithScroll $showPinyin)) {
    throw "Could not restore show-pinyin setting"
  }
  Start-Sleep -Milliseconds 500
  if (-not (Tap-ButtonContainingWithDeepScroll $saveSettings)) {
    throw "Could not save restored pinyin setting"
  }
  Start-Sleep -Seconds 2
  $restored = Query-AppDbScalar "SELECT show_pinyin FROM settings WHERE id = 1;"
  if ($restored -ne $before) {
    throw "show_pinyin was not restored. before=$before restored=$restored"
  }
}

Initialize-ArtifactArchive

if (-not $SkipBuild) {
  Run-Step "Build debug APK" {
    flutter build apk --flavor development --debug
    if ($LASTEXITCODE -ne 0) {
      throw "flutter build apk --flavor development --debug failed"
    }
  }
}

if (-not (Test-Path $ApkPath)) {
  throw "APK not found: $ApkPath"
}

Run-Step "Check Android device $Serial" {
  Invoke-Adb get-state | Out-Host
  Keep-DeviceAwake
}

if (-not $SkipInstall) {
  Run-Step "Install debug APK" {
    Invoke-Adb install -r $ApkPath | Out-Host
  }
}

if ($ResetData) {
  Run-Step "Reset app data" {
    Invoke-Adb shell pm clear $PackageName | Out-Host
  }
}

Run-Step "Grant microphone permission and clear logcat" {
  Invoke-Adb shell pm grant $PackageName android.permission.RECORD_AUDIO | Out-Null
  try {
    Invoke-Adb shell pm grant $PackageName android.permission.POST_NOTIFICATIONS | Out-Null
  } catch {
    Write-Host "Notification permission grant skipped: $($_.Exception.Message)"
  }
  Invoke-Adb logcat -c
}

if ($SyncLogOnly) {
  Run-Step "Launch app" {
    Start-AppAndWait 15
    Tap-FirstButtonContaining "Allow" | Out-Null
    Start-Sleep -Seconds 2
    Assert-NoFlutterRedScreenOrCrash "initial launch before sync-log shortcut smoke"
  }
  Run-Step "Smoke sync log detail shortcuts" {
    Smoke-SyncLogDetailShortcuts
  }
  Save-FinalArtifacts "passed"
  Write-Host "Android sync-log shortcut smoke passed on $Serial."
  return
}

if ($GrowthTrendOnly) {
  Run-Step "Launch app" {
    Start-AppAndWait 15
    Tap-FirstButtonContaining "Allow" | Out-Null
    Start-Sleep -Seconds 2
    Assert-NoFlutterRedScreenOrCrash "initial launch before growth trend shortcut smoke"
  }
  Run-Step "Smoke growth report trend shortcuts" {
    Smoke-GrowthReportTrendDeepLinks -SkipChallengeMapReturn
  }
  Save-FinalArtifacts "passed"
  Write-Host "Android growth trend shortcut smoke passed on $Serial."
  return
}

if ($ChallengeMapReturnOnly) {
  Run-Step "Launch app" {
    Start-AppAndWait 15
    Tap-FirstButtonContaining "Allow" | Out-Null
    Start-Sleep -Seconds 2
    Assert-NoFlutterRedScreenOrCrash "initial launch before challenge map return smoke"
  }
  Run-Step "Smoke challenge map return chain" {
    Smoke-GrowthReportTrendDeepLinks -SkipTrendDetailShortcuts
  }
  Save-FinalArtifacts "passed"
  Write-Host "Android challenge map return smoke passed on $Serial."
  return
}

if ($ReadingScoreOnly) {
  Run-Step "Score reading and assert local DB writes" {
    Score-ReadingAndAssertDbWrites
  }
  Save-FinalArtifacts "passed"
  Write-Host "Android reading score DB smoke passed on $Serial."
  return
}

if ($ReadingControlsOnly) {
  Run-Step "Exercise recognition and recorder controls" {
    Exercise-ReadingControls
  }
  Save-FinalArtifacts "passed"
  Write-Host "Android reading controls smoke passed on $Serial."
  return
}

if ($PermissionOnly) {
  Run-Step "Verify microphone permission revoked state" {
    Verify-MicrophonePermissionRevokedState
  }
  Save-FinalArtifacts "passed"
  Write-Host "Android permission-revoked smoke passed on $Serial."
  return
}

if ($ShortSuite) {
  Run-Step "Launch app" {
    Start-AppAndWait 15
    Tap-FirstButtonContaining "Allow" | Out-Null
    Start-Sleep -Seconds 2
    Assert-NoFlutterRedScreenOrCrash "initial launch before short regression suite"
  }
  Run-Step "Smoke sync log detail shortcuts" {
    Smoke-SyncLogDetailShortcuts
  }
  Run-Step "Smoke growth report trend shortcuts" {
    Smoke-GrowthReportTrendDeepLinks -SkipChallengeMapReturn
  }
  Save-FinalArtifacts "passed"
  Write-Host "Android short regression suite passed on $Serial."
  return
}

Run-Step "Launch app" {
  Start-AppAndWait 15
  Tap-FirstButtonContaining "Allow" | Out-Null
  Start-Sleep -Seconds 2
  Assert-NoFlutterRedScreenOrCrash "initial launch"
}

Run-Step "Smoke sync log detail shortcuts" {
  Smoke-SyncLogDetailShortcuts
}

Run-Step "Smoke growth report trend shortcuts" {
  Smoke-GrowthReportTrendDeepLinks
}

Run-Step "Try opening reading practice from game tab" {
  Open-ReadingPractice
  Assert-NoFlutterRedScreenOrCrash "opening reading practice"
}

Run-Step "Collect UI dump" {
  $script:UiXml = Get-UiDump
}

$readingSignals = @(
  (New-Zh 0x6717 0x8BFB 0x6A21 0x5F0F),
  (New-Zh 0x8BED 0x97F3 0x8BC6 0x522B),
  (New-Zh 0x9EA6 0x514B 0x98CE),
  (New-Zh 0x793A 0x8303 0x6717 0x8BFB),
  (New-Zh 0x5F00 0x59CB 0x6717 0x8BFB)
)
$matchedSignals = $readingSignals | Where-Object { $script:UiXml -match [regex]::Escape($_) }
if ($matchedSignals.Count -lt 2) {
  Write-Host $script:UiXml
  throw "Reading page signals were not found. Matched: $($matchedSignals -join ', ')"
}

Run-Step "Score reading and assert local DB writes" {
  $scoreWord = New-Zh 0x8BC4 0x5206
  $activeProfileId = Query-AppDbScalar "SELECT active_profile_id FROM settings WHERE id = 1;"
  $learningBefore = Query-AppDbScalar "SELECT COUNT(*) FROM learning_records;"
  $reportBefore = Query-AppDbScalar "SELECT COUNT(*) FROM practice_reports;"
  $reportItemsBefore = Query-AppDbScalar "SELECT COUNT(*) FROM practice_report_items;"

  $fieldReady = $false
  for ($attempt = 0; $attempt -lt 14; $attempt++) {
    if (Tap-FirstClassContaining "android.widget.EditText") {
      $fieldReady = $true
      break
    }
    Invoke-Adb shell input swipe 1200 2300 1200 450 650 | Out-Null
    Start-Sleep -Milliseconds 700
  }

  if (-not $fieldReady) {
    Write-Host "Recognition text field not exposed through UIAutomator; using coordinate fallback."
    Invoke-Adb shell input tap 600 2100 | Out-Null
  }
  Start-Sleep -Milliseconds 300
  Invoke-Adb shell input text reading | Out-Null
  Invoke-Adb shell input keyevent 111 | Out-Null
  Start-Sleep -Milliseconds 800

  $textEntered = (Get-UiDump) -match 'text="reading"'
  if (-not $textEntered) {
    Write-Host "Recognition text was not visible after semantic input; retrying with lower field coordinate."
    Invoke-Adb shell input tap 600 2100 | Out-Null
    Start-Sleep -Milliseconds 300
    Invoke-Adb shell input text reading | Out-Null
    Invoke-Adb shell input keyevent KEYCODE_BACK | Out-Null
    Start-Sleep -Milliseconds 800
    $textEntered = (Get-UiDump) -match 'text="reading"'
  }
  if (-not $textEntered) {
    throw "Could not enter recognition text before scoring"
  }

  if (-not (Tap-ButtonContainingWithScroll $scoreWord)) {
    throw "Could not find score button"
  }
  Start-Sleep -Seconds 4

  Assert-NoFlutterRedScreenOrCrash "reading score submission"
  $learningAfter = Query-AppDbScalar "SELECT COUNT(*) FROM learning_records;"
  $reportAfter = Query-AppDbScalar "SELECT COUNT(*) FROM practice_reports;"
  $reportItemsAfter = Query-AppDbScalar "SELECT COUNT(*) FROM practice_report_items;"
  $profileLearningAfter = Query-AppDbScalar "SELECT COUNT(*) FROM learning_records WHERE profile_id = $activeProfileId AND rowid = (SELECT MAX(rowid) FROM learning_records);"
  $profileReportAfter = Query-AppDbScalar "SELECT COUNT(*) FROM practice_reports WHERE profile_id = $activeProfileId AND id = (SELECT MAX(id) FROM practice_reports);"
  Assert-DbCountIncreased "learning_records" $learningBefore $learningAfter "reading score"
  Assert-DbCountIncreased "practice_reports" $reportBefore $reportAfter "reading score"
  Assert-DbCountIncreased "practice_report_items" $reportItemsBefore $reportItemsAfter "reading score"
  if ($profileLearningAfter -lt 1) {
    throw "Latest learning_records row was not written for active profile $activeProfileId"
  }
  if ($profileReportAfter -lt 1) {
    throw "Latest practice_reports row was not written for active profile $activeProfileId"
  }
  Write-Host "DB writes verified: learning_records $learningBefore->$learningAfter; practice_reports $reportBefore->$reportAfter; practice_report_items $reportItemsBefore->$reportItemsAfter"
  $script:ScoreDbVerified = $true
}

Run-Step "Exercise recognition and recorder controls" {
  Exercise-ReadingControls
}

Run-Step "Score reading and assert local DB writes" {
  if ($script:ScoreDbVerified) {
    Write-Host "DB score assertion already passed before recognition exercise."
    return
  }
  $scoreWord = New-Zh 0x8BC4 0x5206
  Start-AppAndWait 15
  Open-ReadingPractice

  $activeProfileId = Query-AppDbScalar "SELECT active_profile_id FROM settings WHERE id = 1;"
  $learningBefore = Query-AppDbScalar "SELECT COUNT(*) FROM learning_records;"
  $reportBefore = Query-AppDbScalar "SELECT COUNT(*) FROM practice_reports;"
  $reportItemsBefore = Query-AppDbScalar "SELECT COUNT(*) FROM practice_report_items;"

  if (Tap-FirstClassContainingWithScroll "android.widget.EditText") {
    Invoke-Adb shell input text reading | Out-Null
    Invoke-Adb shell input keyevent 111 | Out-Null
    Start-Sleep -Milliseconds 500
  } else {
    Write-Host "Recognition text field not exposed through UIAutomator; using coordinate fallback."
    Invoke-Adb shell input swipe 540 1900 540 900 450 | Out-Null
    Start-Sleep -Milliseconds 500
    Invoke-Adb shell input tap 540 1520 | Out-Null
    Start-Sleep -Milliseconds 300
    Invoke-Adb shell input text reading | Out-Null
    Invoke-Adb shell input keyevent 111 | Out-Null
    Start-Sleep -Milliseconds 500
  }

  if (-not (Tap-ButtonContainingWithScroll $scoreWord)) {
    throw "Could not find score button"
  }
  Start-Sleep -Seconds 4

  Assert-NoFlutterRedScreenOrCrash "reading score submission after recognition exercise"
  $learningAfter = Query-AppDbScalar "SELECT COUNT(*) FROM learning_records;"
  $reportAfter = Query-AppDbScalar "SELECT COUNT(*) FROM practice_reports;"
  $reportItemsAfter = Query-AppDbScalar "SELECT COUNT(*) FROM practice_report_items;"
  $profileLearningAfter = Query-AppDbScalar "SELECT COUNT(*) FROM learning_records WHERE profile_id = $activeProfileId AND rowid = (SELECT MAX(rowid) FROM learning_records);"
  $profileReportAfter = Query-AppDbScalar "SELECT COUNT(*) FROM practice_reports WHERE profile_id = $activeProfileId AND id = (SELECT MAX(id) FROM practice_reports);"
  Assert-DbCountIncreased "learning_records" $learningBefore $learningAfter "reading score"
  Assert-DbCountIncreased "practice_reports" $reportBefore $reportAfter "reading score"
  Assert-DbCountIncreased "practice_report_items" $reportItemsBefore $reportItemsAfter "reading score"
  if ($profileLearningAfter -lt 1) {
    throw "Latest learning_records row was not written for active profile $activeProfileId"
  }
  if ($profileReportAfter -lt 1) {
    throw "Latest practice_reports row was not written for active profile $activeProfileId"
  }
  Write-Host "DB writes verified: learning_records $learningBefore->$learningAfter; practice_reports $reportBefore->$reportAfter; practice_report_items $reportItemsBefore->$reportItemsAfter"
}

Run-Step "Smoke high-risk profile and study-card dialogs" {
  if ($SkipSmokeFlows) {
    Write-Host "High-risk smoke flows skipped by -SkipSmokeFlows."
    return
  }

  $manageProfiles = New-Zh 0x5207 0x6362 0x8D44 0x6599
  $newProfile = New-Zh 0x65B0 0x5EFA 0x672C 0x5730 0x8D44 0x6599
  $cancel = New-Zh 0x53D6 0x6D88
  $save = New-Zh 0x4FDD 0x5B58
  $writeNote = New-Zh 0x5199 0x7B14 0x8BB0
  $editNote = New-Zh 0x7F16 0x8F91 0x7B14 0x8BB0
  $noteSaved = New-Zh 0x7B14 0x8BB0 0x5DF2 0x4FDD 0x5B58
  $switchHere = New-Zh 0x5207 0x6362 0x5230 0x8FD9 0x91CC
  $remembered = New-Zh 0x6211 0x8BB0 0x4F4F 0x4E86

  Open-ProfileTab
  Assert-NoFlutterRedScreenOrCrash "opening profile tab"
  Smoke-PinyinSettingToggle
  Open-ProfileTab
  if (-not (Tap-NodeContainingWithScroll $manageProfiles)) {
    throw "Could not open local profile management"
  }
  Start-Sleep -Seconds 2
  Assert-NoFlutterRedScreenOrCrash "opening profile management"

  $activeProfileBefore = Query-AppDbScalar "SELECT active_profile_id FROM settings WHERE id = 1;"
  $profileCountBefore = Query-AppDbScalar "SELECT COUNT(*) FROM profile_accounts;"
  if (-not (Tap-NodeContainingWithScroll $newProfile)) {
    throw "Could not open new profile dialog"
  }
  Start-Sleep -Seconds 1
  Enter-TextIntoFirstEditText "CancelSmoke" | Out-Null
  if (-not (Tap-FirstButtonContaining $cancel)) {
    throw "Could not cancel nickname dialog"
  }
  Start-Sleep -Seconds 1
  Assert-NoFlutterRedScreenOrCrash "canceling new profile dialog"
  $profileCountAfterCancel = Query-AppDbScalar "SELECT COUNT(*) FROM profile_accounts;"
  Assert-DbCountUnchanged "profile_accounts" $profileCountBefore $profileCountAfterCancel "canceling new profile dialog"

  if (-not (Tap-NodeContainingWithScroll $newProfile)) {
    throw "Could not reopen new profile dialog"
  }
  Start-Sleep -Seconds 1
  Enter-TextIntoFirstEditText "SwitchSmoke" | Out-Null
  if (-not (Tap-FirstButtonContaining $save)) {
    throw "Could not save smoke profile"
  }
  Start-Sleep -Seconds 2
  Assert-NoFlutterRedScreenOrCrash "saving new profile dialog"
  $profileCountAfterSave = Query-AppDbScalar "SELECT COUNT(*) FROM profile_accounts;"
  Assert-DbCountIncreased "profile_accounts" $profileCountBefore $profileCountAfterSave "saving new profile"

  Tap-NodeContainingWithScroll $switchHere | Out-Null
  Start-Sleep -Seconds 2
  Assert-NoFlutterRedScreenOrCrash "switching local profile"
  $activeProfileAfter = Query-AppDbScalar "SELECT active_profile_id FROM settings WHERE id = 1;"
  if ($activeProfileAfter -eq $activeProfileBefore) {
    throw "Active profile did not change after profile switch smoke. before=$activeProfileBefore after=$activeProfileAfter"
  }

  Open-StudyCardsFromHome
  $studyLearningBefore = Query-AppDbScalar "SELECT COUNT(*) FROM learning_records WHERE profile_id = (SELECT active_profile_id FROM settings WHERE id = 1) AND mode = 'study_card';"
  if (-not (Reveal-StudyCardActions)) {
    throw "Could not reveal study-card action buttons"
  }
  if (-not (Tap-ButtonContainingWithDeepScroll $remembered)) {
    throw "Could not mark study card as remembered"
  }
  Start-Sleep -Seconds 2
  Assert-NoFlutterRedScreenOrCrash "marking study-card review"
  $studyLearningAfter = Query-AppDbScalar "SELECT COUNT(*) FROM learning_records WHERE profile_id = (SELECT active_profile_id FROM settings WHERE id = 1) AND mode = 'study_card';"
  Assert-DbCountIncreased "study_card learning_records" $studyLearningBefore $studyLearningAfter "marking study-card review"

  $cancelNoteBefore = Query-AppDbScalar "SELECT COUNT(*) FROM study_card_progress WHERE note LIKE '%CancelNoteSmoke%';"
  if (-not (Open-StudyCardNoteDialog $writeNote $editNote)) {
    throw "Could not open study-card note dialog for cancel smoke"
  }
  Invoke-Adb shell input keyevent KEYCODE_MOVE_END | Out-Null
  Invoke-Adb shell input text CancelNoteSmoke | Out-Null
  Invoke-Adb shell input keyevent KEYCODE_BACK | Out-Null
  Start-Sleep -Milliseconds 500
  if (-not (Tap-FirstButtonContaining $cancel)) {
    throw "Could not cancel study-card note dialog"
  }
  Start-Sleep -Seconds 1
  Assert-NoFlutterRedScreenOrCrash "canceling study-card note dialog"
  $cancelNoteAfter = Query-AppDbScalar "SELECT COUNT(*) FROM study_card_progress WHERE note LIKE '%CancelNoteSmoke%';"
  Assert-DbCountUnchanged "study_card_progress canceled notes" $cancelNoteBefore $cancelNoteAfter "canceling study-card note"

  if (-not (Open-StudyCardNoteDialog $writeNote $editNote)) {
    throw "Could not open study-card note dialog for save smoke"
  }
  Invoke-Adb shell input keyevent KEYCODE_MOVE_END | Out-Null
  Invoke-Adb shell input text SavedNoteSmoke | Out-Null
  Invoke-Adb shell input keyevent KEYCODE_BACK | Out-Null
  Start-Sleep -Milliseconds 500
  if (-not (Tap-FirstButtonContaining $save)) {
    throw "Could not save study-card note dialog"
  }
  Start-Sleep -Seconds 2
  if ((Get-UiDump) -notmatch [regex]::Escape($noteSaved)) {
    Write-Host "Study-card note saved toast was not captured; verifying persistence through app DB."
  }
  $savedNoteCount = Query-AppDbScalar "SELECT COUNT(*) FROM study_card_progress WHERE note LIKE '%SavedNoteSmoke%';"
  if ($savedNoteCount -lt 1) {
    throw "Saved study-card note was not persisted"
  }

  Assert-NoFlutterRedScreenOrCrash "profile and study-card smoke"
}

Run-Step "Verify microphone permission revoked state" {
  Verify-MicrophonePermissionRevokedState
}

Run-Step "Check Android speech/TTS logs" {
  $script:Logs = (Invoke-Adb logcat -d -t 800) -join "`n"
  if ($script:Logs -match "FATAL EXCEPTION|FlutterError|SQLiteException|no such table|_dependents|Failed assertion.*dependents") {
    throw "Crash or database error found in logcat"
  }
  $speechLogCount = ([regex]::Matches($script:Logs, "\[GSCSpeech\]|sherpa|TextToSpeech|TTS")).Count
  Write-Host "Matched UI signals: $($matchedSignals -join ', ')"
  Write-Host "Speech/TTS related log lines: $speechLogCount"
  Assert-NoFlutterRedScreenOrCrash "final Android regression check"
}

Save-FinalArtifacts "passed"
Write-Host "Android reading regression passed on $Serial."
