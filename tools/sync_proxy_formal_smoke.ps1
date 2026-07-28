$ErrorActionPreference = "Stop"

if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
  throw "node is not available in PATH."
}

$port = 8790
$dbPath = Join-Path $env:TEMP "gscappall-sync-proxy-smoke.sqlite"
if (Test-Path $dbPath) {
  Remove-Item -LiteralPath $dbPath -Force
}
$previousPort = $env:PORT
$previousDb = $env:SYNC_PROXY_DB
$serverOut = Join-Path $env:TEMP "gscappall-sync-proxy-formal-smoke.out.log"
$serverErr = Join-Path $env:TEMP "gscappall-sync-proxy-formal-smoke.err.log"
Remove-Item -LiteralPath $serverOut, $serverErr -Force -ErrorAction SilentlyContinue
$env:PORT = "$port"
$env:SYNC_PROXY_DB = $dbPath
$server = Start-Process `
  -FilePath "node" `
  -ArgumentList "tools\sync-proxy\server.js" `
  -WorkingDirectory (Get-Location) `
  -RedirectStandardOutput $serverOut `
  -RedirectStandardError $serverErr `
  -WindowStyle Hidden `
  -PassThru

try {
  $ready = $false
  for ($attempt = 0; $attempt -lt 120; $attempt += 1) {
    try {
      Invoke-RestMethod `
        -Method Get `
        -Uri "http://127.0.0.1:$port/health" `
        -TimeoutSec 5 | Out-Null
      $ready = $true
      break
    } catch {
      Start-Sleep -Milliseconds 500
    }
  }
  if (-not $ready) {
    Write-Host "--- sync-proxy stdout ---"
    Get-Content $serverOut -ErrorAction SilentlyContinue | Out-Host
    Write-Host "--- sync-proxy stderr ---"
    Get-Content $serverErr -ErrorAction SilentlyContinue | Out-Host
    throw "sync-proxy did not become ready on port $port."
  }

  $registerBody = @{
    accountId = "account-a"
    password = "formal-pass-a"
    profileIds = @(1, 2)
  } | ConvertTo-Json -Depth 4
  $registered = Invoke-RestMethod `
    -Method Post `
    -Uri "http://127.0.0.1:$port/auth/register" `
    -ContentType "application/json; charset=utf-8" `
    -Body $registerBody
  if (-not $registered.refreshToken) {
    throw "Register did not return a refresh token."
  }
  $refreshBody = @{
    accountId = "account-a"
    refreshToken = $registered.refreshToken
  } | ConvertTo-Json -Depth 4
  $refresh = Invoke-RestMethod `
    -Method Post `
    -Uri "http://127.0.0.1:$port/auth/refresh" `
    -ContentType "application/json; charset=utf-8" `
    -Body $refreshBody

  $headers = @{
    Authorization = "Bearer $($refresh.accessToken)"
    "X-GSC-Account-Id" = "account-a"
    "X-GSC-Profile-Ids" = "1"
    "X-GSC-Device-Id" = "formal-smoke-device"
    "X-GSC-App-Version" = "dev"
    "X-GSC-Schema-Version" = "10"
  }
  $headers2 = @{
    Authorization = "Bearer $($refresh.accessToken)"
    "X-GSC-Account-Id" = "account-a"
    "X-GSC-Profile-Ids" = "1"
    "X-GSC-Device-Id" = "formal-smoke-device-2"
    "X-GSC-App-Version" = "dev"
    "X-GSC-Schema-Version" = "10"
  }
  $headersAllProfiles = @{
    Authorization = "Bearer $($refresh.accessToken)"
    "X-GSC-Account-Id" = "account-a"
    "X-GSC-Profile-Ids" = "1,2"
    "X-GSC-Device-Id" = "formal-smoke-device"
    "X-GSC-App-Version" = "dev"
    "X-GSC-Schema-Version" = "10"
  }

  $capabilities = Invoke-RestMethod `
    -Method Get `
    -Uri "http://127.0.0.1:$port/sync/capabilities" `
    -Headers $headers
  if ($capabilities.maxBatchSize -ne 500) {
    throw "Unexpected maxBatchSize: $($capabilities.maxBatchSize)"
  }

  $oversizedFavorites = @()
  for ($index = 0; $index -lt 501; $index += 1) {
    $oversizedFavorites += @{
      recordKey = "favorite:1:oversized-$index"
      profileId = 1
      poemId = $index
      metadata = @{
        updatedAt = "2026-05-11T09:59:00.000Z"
        isDeleted = $false
      }
    }
  }
  $oversizedBody = @{
    requestId = "formal-smoke-oversized"
    device = @{
      deviceId = "formal-smoke-device"
      platform = "powershell"
      appVersion = "dev"
      schemaVersion = 10
    }
    checkpoint = @{
      globalCursor = $null
      collectionCursors = @{}
      schemaVersion = 10
    }
    batch = @{
      favorites = $oversizedFavorites
    }
  } | ConvertTo-Json -Depth 8
  try {
    Invoke-RestMethod `
      -Method Post `
      -Uri "http://127.0.0.1:$port/sync/push" `
      -Headers $headers `
      -ContentType "application/json; charset=utf-8" `
      -Body $oversizedBody | Out-Null
    throw "Oversized batch was accepted."
  } catch {
    if ($_.Exception.Response.StatusCode.value__ -ne 413) {
      throw
    }
  }

  $pushBody = @{
    requestId = "formal-smoke-push"
    device = @{
      deviceId = "formal-smoke-device"
      platform = "powershell"
      appVersion = "dev"
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
          recordKey = "favorite:1:1"
          profileId = 1
          poemId = 1
          metadata = @{
            updatedAt = "2026-05-11T10:00:00.000Z"
            deletedAt = "2026-05-11T10:00:00.000Z"
            isDeleted = $true
          }
        }
      )
    }
    generatedAt = "2026-05-11T10:00:00.000Z"
  } | ConvertTo-Json -Depth 8

  $push = Invoke-RestMethod `
    -Method Post `
    -Uri "http://127.0.0.1:$port/sync/push" `
    -Headers $headers2 `
    -ContentType "application/json; charset=utf-8" `
    -Body $pushBody
  if ($push.acceptedCounts.favorites -ne 1) {
    throw "Push did not ACK favorites."
  }

  $pullBody = @{
    device = @{
      deviceId = "formal-smoke-device"
      platform = "powershell"
      appVersion = "dev"
      schemaVersion = 10
    }
    checkpoint = @{
      globalCursor = $null
      collectionCursors = @{}
      schemaVersion = 10
    }
    requestedAt = "2026-05-11T10:01:00.000Z"
  } | ConvertTo-Json -Depth 8

  $pull = Invoke-RestMethod `
    -Method Post `
    -Uri "http://127.0.0.1:$port/sync/pull" `
    -Headers $headers `
    -ContentType "application/json; charset=utf-8" `
    -Body $pullBody
  if ($pull.receivedCounts.favorites -ne 1) {
    throw "Pull did not return the pushed favorite."
  }

  $stalePushBody = @{
    requestId = "formal-smoke-stale-soft-delete"
    device = @{
      deviceId = "formal-smoke-device-2"
      platform = "powershell"
      appVersion = "dev"
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
          recordKey = "favorite:1:1"
          profileId = 1
          poemId = 1
          metadata = @{
            updatedAt = "2026-05-11T09:00:00.000Z"
            deletedAt = $null
            isDeleted = $false
          }
        }
      )
    }
    generatedAt = "2026-05-11T10:02:00.000Z"
  } | ConvertTo-Json -Depth 10

  $stalePush = Invoke-RestMethod `
    -Method Post `
    -Uri "http://127.0.0.1:$port/sync/push" `
    -Headers $headers `
    -ContentType "application/json; charset=utf-8" `
    -Body $stalePushBody
  if ($stalePush.conflicts.Count -lt 1) {
    throw "Soft-delete/LWW conflict was not detected."
  }

  $mergeSeedBody = @{
    requestId = "formal-smoke-merge-seed"
    device = @{
      deviceId = "formal-smoke-device"
      platform = "powershell"
      appVersion = "dev"
      schemaVersion = 10
    }
    checkpoint = @{
      globalCursor = $null
      collectionCursors = @{}
      schemaVersion = 10
    }
    batch = @{
      userPoints = @(
        @{
          recordKey = "points:1"
          profileId = 1
          totalPoints = 10
          metadata = @{
            updatedAt = "2026-05-11T10:00:00.000Z"
            isDeleted = $false
          }
        }
      )
    }
    generatedAt = "2026-05-11T10:03:00.000Z"
  } | ConvertTo-Json -Depth 10
  Invoke-RestMethod `
    -Method Post `
    -Uri "http://127.0.0.1:$port/sync/push" `
    -Headers $headers `
    -ContentType "application/json; charset=utf-8" `
    -Body $mergeSeedBody | Out-Null

  $mergeConflictBody = @{
    requestId = "formal-smoke-merge-conflict"
    device = @{
      deviceId = "formal-smoke-device-2"
      platform = "powershell"
      appVersion = "dev"
      schemaVersion = 10
    }
    checkpoint = @{
      globalCursor = $null
      collectionCursors = @{}
      schemaVersion = 10
    }
    batch = @{
      userPoints = @(
        @{
          recordKey = "points:1"
          profileId = 1
          totalPoints = 12
          metadata = @{
            updatedAt = "2026-05-11T10:04:00.000Z"
            isDeleted = $false
          }
        }
      )
    }
    generatedAt = "2026-05-11T10:04:00.000Z"
  } | ConvertTo-Json -Depth 10
  $mergeConflict = Invoke-RestMethod `
    -Method Post `
    -Uri "http://127.0.0.1:$port/sync/conflicts/preview" `
    -Headers $headers2 `
    -ContentType "application/json; charset=utf-8" `
    -Body $mergeConflictBody
  if ($mergeConflict.conflicts[0].recommendedWinner -ne "merged") {
    throw "Server merge suggestion was not returned."
  }

  $fullResourceBody = @{
    requestId = "formal-smoke-full-resource"
    device = @{
      deviceId = "formal-smoke-device"
      platform = "powershell"
      appVersion = "dev"
      schemaVersion = 10
    }
    checkpoint = @{
      globalCursor = $null
      collectionCursors = @{}
      schemaVersion = 10
    }
    batch = @{
      poems = @(
        @{
          recordKey = "poem:catalog:full-resource"
          poemId = 9001
          title = "Full Resource Poem"
          author = "Smoke"
          content = "A full resource replay sample."
          metadata = @{
            updatedAt = "2026-05-11T10:10:00.000Z"
            isDeleted = $false
          }
        }
      )
      favorites = @(
        @{
          recordKey = "favorite:2:9001"
          profileId = 2
          poemId = 9001
          isFavorite = $true
          metadata = @{
            updatedAt = "2026-05-11T10:10:01.000Z"
            isDeleted = $false
          }
        }
      )
      learningRecords = @(
        @{
          recordKey = "learning:2:9001:2026-05-11T10:10:02.000Z"
          profileId = 2
          poemId = 9001
          mode = "poetry_jielong"
          stageId = "jielong_entry"
          score = 88
          metadata = @{
            createdAt = "2026-05-11T10:10:02.000Z"
            updatedAt = "2026-05-11T10:10:02.000Z"
            isDeleted = $false
          }
        }
      )
      studyCardProgress = @(
        @{
          recordKey = "study_card:2:9001"
          profileId = 2
          poemId = 9001
          memoryStatus = "reviewing"
          reviewCount = 3
          nextReviewAt = "2026-05-12T10:10:03.000Z"
          metadata = @{
            updatedAt = "2026-05-11T10:10:03.000Z"
            isDeleted = $false
          }
        }
      )
      reciteRecords = @(
        @{
          recordKey = "recite:2:9001:2026-05-11T10:10:04.000Z"
          profileId = 2
          poemId = 9001
          score = 82
          recognizedText = "sample"
          transcriptVersion = "mock-v1"
          metadata = @{
            createdAt = "2026-05-11T10:10:04.000Z"
            updatedAt = "2026-05-11T10:10:04.000Z"
            isDeleted = $false
          }
        }
      )
      wrongQuestions = @(
        @{
          recordKey = "wrong:2:9001:2026-05-11T10:10:05.000Z"
          profileId = 2
          poemId = 9001
          questionType = "dictation"
          prompt = "sample"
          correctAnswer = "answer"
          userAnswer = "wrong"
          severity = "high"
          isResolved = $false
          metadata = @{
            updatedAt = "2026-05-11T10:10:05.000Z"
            isDeleted = $false
          }
        }
      )
      practiceReports = @(
        @{
          recordKey = "report:2:full-resource-session"
          profileId = 2
          sessionId = "full-resource-session"
          mode = "dictation"
          poemId = 9001
          totalScore = 78
          correctCount = 7
          totalQuestions = 10
          generatedWrongCount = 1
          completedAt = "2026-05-11T10:10:06.000Z"
          items = @(
            @{
              lineIndex = 0
              prompt = "sample"
              expectedAnswer = "answer"
              userAnswer = "wrong"
              isCorrect = $false
              score = 50
              mistakeType = "typo"
            }
          )
          metadata = @{
            updatedAt = "2026-05-11T10:10:06.000Z"
            isDeleted = $false
          }
        }
      )
      dailyPoemRecords = @(
        @{
          recordKey = "daily:2:2026-05-11"
          profileId = 2
          dateKey = "2026-05-11"
          poemId = 9001
          isCompleted = $true
          completedAt = "2026-05-11T10:10:07.000Z"
          metadata = @{
            updatedAt = "2026-05-11T10:10:07.000Z"
            isDeleted = $false
          }
        }
      )
      userPoints = @(
        @{
          recordKey = "points:2"
          profileId = 2
          totalPoints = 120
          currentPoints = 80
          totalCheckIns = 6
          consecutiveDays = 3
          lastCheckInDate = "2026-05-11"
          metadata = @{
            updatedAt = "2026-05-11T10:10:08.000Z"
            isDeleted = $false
          }
        }
      )
      challengeStageRewards = @(
        @{
          recordKey = "reward:2:jielong_entry:3"
          profileId = 2
          stageId = "jielong_entry"
          stars = 3
          claimedAt = "2026-05-11T10:10:09.000Z"
          metadata = @{
            updatedAt = "2026-05-11T10:10:09.000Z"
            isDeleted = $false
          }
        }
      )
      settings = @(
        @{
          recordKey = "settings:1"
          activeProfileId = 2
          showPinyin = $true
          themeMode = "system"
          fontScale = 1.0
          speechRate = 1.0
          dailyReminderEnabled = $true
          notificationsEnabled = $true
          reminderHour = 7
          reminderMinute = 30
          seedVersion = "smoke"
          metadata = @{
            updatedAt = "2026-05-11T10:10:10.000Z"
            isDeleted = $false
          }
        }
      )
      userProfiles = @(
        @{
          recordKey = "profile:2"
          profileId = 2
          nickname = "Profile Two"
          tagline = "Full resource smoke"
          avatarSeed = "profile-two"
          lastActiveAt = "2026-05-11T10:10:11.000Z"
          metadata = @{
            updatedAt = "2026-05-11T10:10:11.000Z"
            isDeleted = $false
          }
        }
      )
    }
    generatedAt = "2026-05-11T10:10:12.000Z"
  } | ConvertTo-Json -Depth 20

  $fullResourcePush = Invoke-RestMethod `
    -Method Post `
    -Uri "http://127.0.0.1:$port/sync/push" `
    -Headers $headersAllProfiles `
    -ContentType "application/json; charset=utf-8" `
    -Body $fullResourceBody
  foreach ($resourceName in @(
    "poems",
    "favorites",
    "learning_records",
    "study_card_progress",
    "recite_records",
    "wrong_questions",
    "practice_reports",
    "daily_poem_records",
    "user_points",
    "challenge_stage_rewards",
    "settings",
    "user_profiles"
  )) {
    if ($fullResourcePush.acceptedCounts.$resourceName -ne 1) {
      throw "Full-resource push did not ACK $resourceName."
    }
  }

  $fullPull = Invoke-RestMethod `
    -Method Post `
    -Uri "http://127.0.0.1:$port/sync/pull" `
    -Headers $headersAllProfiles `
    -ContentType "application/json; charset=utf-8" `
    -Body $pullBody
  if ($fullPull.receivedCounts.learning_records -lt 1 -or
      $fullPull.receivedCounts.challenge_stage_rewards -lt 1) {
    throw "Full-resource pull did not return profile 2 progress data."
  }

  $profileOneOnlyPull = Invoke-RestMethod `
    -Method Post `
    -Uri "http://127.0.0.1:$port/sync/pull" `
    -Headers $headers `
    -ContentType "application/json; charset=utf-8" `
    -Body $pullBody
  if ($profileOneOnlyPull.receivedCounts.learning_records -ge 1 -or
      $profileOneOnlyPull.receivedCounts.challenge_stage_rewards -ge 1) {
    throw "Profile isolation failed: profile 1 pull received profile 2 progress data."
  }

  $accountBHeaders = @{
    "X-GSC-Account-Id" = "account-b"
    "X-GSC-Profile-Ids" = "1"
    "X-GSC-Device-Id" = "formal-smoke-device"
    "X-GSC-App-Version" = "dev"
    "X-GSC-Schema-Version" = "10"
  }
  $registerBBody = @{
    accountId = "account-b"
    password = "formal-pass-b"
    profileIds = @(1)
  } | ConvertTo-Json -Depth 4
  $refreshB = Invoke-RestMethod `
    -Method Post `
    -Uri "http://127.0.0.1:$port/auth/register" `
    -ContentType "application/json; charset=utf-8" `
    -Body $registerBBody
  $accountBHeaders.Authorization = "Bearer $($refreshB.accessToken)"
  $accountBPull = Invoke-RestMethod `
    -Method Post `
    -Uri "http://127.0.0.1:$port/sync/pull" `
    -Headers $accountBHeaders `
    -ContentType "application/json; charset=utf-8" `
    -Body $pullBody
  if ($accountBPull.receivedCounts.favorites -eq 1) {
    throw "Account isolation failed: account-b received account-a data."
  }

  $forbiddenBody = @{
    requestId = "formal-smoke-profile-forbidden"
    device = @{
      deviceId = "formal-smoke-device"
      platform = "powershell"
      appVersion = "dev"
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
          recordKey = "favorite:3:1"
          profileId = 3
          poemId = 1
          metadata = @{
            updatedAt = "2026-05-11T10:05:00.000Z"
            isDeleted = $false
          }
        }
      )
    }
    generatedAt = "2026-05-11T10:05:00.000Z"
  } | ConvertTo-Json -Depth 10
  try {
    Invoke-RestMethod `
      -Method Post `
      -Uri "http://127.0.0.1:$port/sync/push" `
      -Headers $headers `
      -ContentType "application/json; charset=utf-8" `
      -Body $forbiddenBody | Out-Null
    throw "Profile authorization failed: profile 3 was accepted."
  } catch {
    if ($_.Exception.Response.StatusCode.value__ -ne 403) {
      throw
    }
  }

  Write-Host "formal sync-proxy smoke passed."
} finally {
  if ($server -and -not $server.HasExited) {
    Stop-Process -Id $server.Id -Force
  }
  $env:PORT = $previousPort
  $env:SYNC_PROXY_DB = $previousDb
}
