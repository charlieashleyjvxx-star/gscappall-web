$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$sourceFile = 'D:\GSCapp\gushici-app\src\data\poemsData.ts'
$outputDir = Join-Path $projectRoot 'assets\seed'

if (-not (Test-Path $sourceFile)) {
  throw "Seed source file not found: $sourceFile"
}

function Join-Chars {
  param([int[]]$CodePoints)
  return -join ($CodePoints | ForEach-Object { [char]$_ })
}

function Get-GradeStateFromLine {
  param([string]$Line)

  if ($Line -match '^\s*//\s*\u4e00\u5e74\u7ea7\s*$') {
    return @{ label = (Join-Chars @(0x4e00, 0x5e74, 0x7ea7)); number = 1 }
  }
  if ($Line -match '^\s*//\s*\u4e8c\u5e74\u7ea7\s*$') {
    return @{ label = (Join-Chars @(0x4e8c, 0x5e74, 0x7ea7)); number = 2 }
  }
  if ($Line -match '^\s*//\s*\u4e09\u5e74\u7ea7\s*$') {
    return @{ label = (Join-Chars @(0x4e09, 0x5e74, 0x7ea7)); number = 3 }
  }
  if ($Line -match '^\s*//\s*\u56db\u5e74\u7ea7\s*$') {
    return @{ label = (Join-Chars @(0x56db, 0x5e74, 0x7ea7)); number = 4 }
  }
  if ($Line -match '^\s*//\s*\u4e94\u5e74\u7ea7\s*$') {
    return @{ label = (Join-Chars @(0x4e94, 0x5e74, 0x7ea7)); number = 5 }
  }
  if ($Line -match '^\s*//\s*\u516d\u5e74\u7ea7\s*$') {
    return @{ label = (Join-Chars @(0x516d, 0x5e74, 0x7ea7)); number = 6 }
  }

  return $null
}

function Convert-ObjectLiteralToPoem {
  param(
    [string]$ObjectLiteral,
    [string]$GradeLabel,
    [int]$GradeNumber,
    [int]$Order,
    [string]$SeedVersion
  )

  $jsonish = [regex]::Replace(
    $ObjectLiteral,
    '(?m)^(\s*)([A-Za-z_][A-Za-z0-9_]*)\s*:',
    '$1"$2":'
  )
  $jsonish = [regex]::Replace($jsonish, '\}\s*,\s*$', '}')

  try {
    $parsed = $jsonish | ConvertFrom-Json
  } catch {
    Write-Output 'Failed to parse object literal:'
    Write-Output $jsonish
    throw
  }

  return [ordered]@{
    id = $Order
    title = $parsed.title
    author = $parsed.author
    dynasty = $parsed.dynasty
    grade = $GradeNumber
    gradeLabel = $GradeLabel
    category = $parsed.category
    content = $parsed.content
    pinyin = $parsed.pinyin
    annotation = $parsed.annotation
    translation = $parsed.translation
    appreciation = $parsed.appreciation
    authorIntro = $parsed.authorIntro
    extension = $parsed.extension
    audioUrl = $parsed.audioUrl
    imageUrl = $parsed.imageUrl
    difficulty = $parsed.difficulty
    source = @{
      project = 'GSCapp'
      file = 'gushici-app/src/data/poemsData.ts'
      seedVersion = $SeedVersion
      sortOrder = $Order
    }
  }
}

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$sourceLines = Get-Content -Path $sourceFile -Encoding utf8
$sourceText = Get-Content -Path $sourceFile -Encoding utf8 -Raw

$dataVersion = 'unknown'
$versionMatch = [regex]::Match($sourceText, 'export const DATA_VERSION = "([^"]+)"')
if ($versionMatch.Success) {
  $dataVersion = $versionMatch.Groups[1].Value
}

$defaultGrade = Join-Chars @(0x672a, 0x5206, 0x7ea7)
$currentGradeLabel = $defaultGrade
$currentGradeNumber = 0
$poems = New-Object System.Collections.Generic.List[object]
$buffer = New-Object System.Collections.Generic.List[string]
$braceDepth = 0
$inObject = $false
$sortOrder = 0

foreach ($line in $sourceLines) {
  $gradeState = Get-GradeStateFromLine -Line $line
  if ($null -ne $gradeState) {
    $currentGradeLabel = $gradeState.label
    $currentGradeNumber = $gradeState.number
    continue
  }

  if (-not $inObject -and $line -match '^\s*\{') {
    $inObject = $true
    $buffer.Clear()
    $buffer.Add($line) | Out-Null
    $braceDepth = ([regex]::Matches($line, '\{').Count - [regex]::Matches($line, '\}').Count)
    if ($braceDepth -eq 0) {
      $sortOrder += 1
      $poems.Add((Convert-ObjectLiteralToPoem -ObjectLiteral ($buffer -join "`n") -GradeLabel $currentGradeLabel -GradeNumber $currentGradeNumber -Order $sortOrder -SeedVersion $dataVersion)) | Out-Null
      $inObject = $false
    }
    continue
  }

  if ($inObject) {
    $buffer.Add($line) | Out-Null
    $braceDepth += ([regex]::Matches($line, '\{').Count - [regex]::Matches($line, '\}').Count)
    if ($braceDepth -eq 0) {
      $sortOrder += 1
      $poems.Add((Convert-ObjectLiteralToPoem -ObjectLiteral ($buffer -join "`n") -GradeLabel $currentGradeLabel -GradeNumber $currentGradeNumber -Order $sortOrder -SeedVersion $dataVersion)) | Out-Null
      $inObject = $false
    }
  }
}

$gradeSummary = @()
$categorySummary = @()
$dynastySummary = @()

foreach ($group in ($poems | Group-Object { $_['gradeLabel'] } | Sort-Object Name)) {
  $gradeSummary += [ordered]@{
    gradeLabel = $group.Name
    count = $group.Count
  }
}

foreach ($group in ($poems | Group-Object { $_['category'] } | Sort-Object Count -Descending)) {
  $categorySummary += [ordered]@{
    category = $group.Name
    count = $group.Count
  }
}

foreach ($group in ($poems | Group-Object { $_['dynasty'] } | Sort-Object Count -Descending)) {
  $dynastySummary += [ordered]@{
    dynasty = $group.Name
    count = $group.Count
  }
}

$manifest = [ordered]@{
  sourceProject = 'GSCapp'
  sourceFile = 'D:\GSCapp\gushici-app\src\data\poemsData.ts'
  extractedAt = (Get-Date).ToString('s')
  seedVersion = $dataVersion
  poemCount = $poems.Count
  gradeSummary = $gradeSummary
  categorySummary = $categorySummary
  dynastySummary = $dynastySummary
}

$poemsPath = Join-Path $outputDir 'poems_seed.json'
$manifestPath = Join-Path $outputDir 'seed_manifest.json'

$poems | ConvertTo-Json -Depth 10 | Set-Content -Path $poemsPath -Encoding utf8
$manifest | ConvertTo-Json -Depth 10 | Set-Content -Path $manifestPath -Encoding utf8

Write-Output 'Seed extraction complete.'
Write-Output "Poems: $($poems.Count)"
Write-Output "Version: $dataVersion"
Write-Output "Seed: $poemsPath"
Write-Output "Manifest: $manifestPath"
