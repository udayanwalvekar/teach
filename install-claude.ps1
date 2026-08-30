param(
  [switch]$Force
)

$ErrorActionPreference = "Stop"

$SourceDir = Join-Path $PSScriptRoot "plugins/teach/skills/teach"
$DefaultDestination = Join-Path $HOME ".claude/skills/teach"
$Destination = if ($env:TEACH_CLAUDE_DESTINATION) { $env:TEACH_CLAUDE_DESTINATION } else { $DefaultDestination }

if (-not (Test-Path (Join-Path $SourceDir "SKILL.md") -PathType Leaf)) {
  throw "Teach skill source was not found at $SourceDir"
}

$Python3Available = $false
foreach ($Candidate in @(
  @{ Command = "py"; Arguments = @("-3") },
  @{ Command = "python3"; Arguments = @() },
  @{ Command = "python"; Arguments = @() }
)) {
  if (Get-Command $Candidate.Command -ErrorAction SilentlyContinue) {
    $PythonArguments = @($Candidate.Arguments) + @("-c", "import sys; raise SystemExit(sys.version_info < (3, 9))")
    & $Candidate.Command $PythonArguments 2>$null
    if ($LASTEXITCODE -eq 0) {
      $Python3Available = $true
      break
    }
  }
}

if (-not $Python3Available) {
  throw "Teach needs Python 3.9 or newer. Install Python 3, then run this installer again."
}

if ((Test-Path $Destination) -and -not $Force) {
  throw "Teach is already installed at $Destination. Run .\install-claude.ps1 -Force to update it; the existing copy will be backed up."
}

$DestinationParent = Split-Path -Parent $Destination
New-Item -ItemType Directory -Force -Path $DestinationParent | Out-Null
$StagingRoot = Join-Path $DestinationParent (".teach-install-" + [guid]::NewGuid().ToString("N"))
$StagedSkill = Join-Path $StagingRoot "teach"
$Backup = $null
$Installed = $false

try {
  New-Item -ItemType Directory -Path $StagedSkill | Out-Null

  $SkillText = [IO.File]::ReadAllText((Join-Path $SourceDir "SKILL.md"))
  $FrontmatterEnd = $SkillText.IndexOf("`n---", 4)
  if ($FrontmatterEnd -lt 0) {
    throw "Teach SKILL.md has invalid frontmatter."
  }
  $SkillText = $SkillText.Insert($FrontmatterEnd, "`ndisable-model-invocation: true")
  $SkillText += "`n`n## Builder request`n`n`$ARGUMENTS`n"
  [IO.File]::WriteAllText(
    (Join-Path $StagedSkill "SKILL.md"),
    $SkillText,
    [Text.UTF8Encoding]::new($false)
  )

  foreach ($ResourceDir in @("assets", "examples", "references", "scripts")) {
    $ResourceSource = Join-Path $SourceDir $ResourceDir
    if (Test-Path $ResourceSource -PathType Container) {
      Copy-Item -Recurse -Path $ResourceSource -Destination (Join-Path $StagedSkill $ResourceDir)
    }
  }

  if (Test-Path $Destination) {
    $Backup = "$Destination.backup-$([DateTime]::UtcNow.ToString('yyyyMMddHHmmss'))-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    Move-Item -Path $Destination -Destination $Backup
    Write-Host "Backed up the previous Teach skill to $Backup"
  }

  Move-Item -Path $StagedSkill -Destination $Destination
  $Installed = $true
}
catch {
  if (-not $Installed -and $Backup -and (Test-Path $Backup) -and -not (Test-Path $Destination)) {
    Move-Item -Path $Backup -Destination $Destination
    Write-Warning "Install failed; restored the previous Teach skill at $Destination"
  }
  throw
}
finally {
  if (Test-Path $StagingRoot) {
    Remove-Item -Recurse -Force -Path $StagingRoot
  }
}

function Test-TeachInteractiveTerminal {
  if (-not [Environment]::UserInteractive -or $env:NO_COLOR) {
    return $false
  }

  try {
    return -not [Console]::IsOutputRedirected
  }
  catch {
    return $false
  }
}

function Show-TeachSuccess {
  if (-not (Test-TeachInteractiveTerminal)) {
    Write-Output "Installed Teach for Claude Code at $Destination"
    Write-Output "Start or restart Claude Code, finish a build chat, then run /teach"
    return
  }

  Write-Host ""
  foreach ($Frame in @(".  ", ".. ", "...")) {
    Write-Host "`r  Preparing Teach$Frame" -NoNewline -ForegroundColor DarkGray
    Start-Sleep -Milliseconds 110
  }
  Write-Host "`r$(' ' * 34)`r" -NoNewline

  $ContentLines = @(
    "* TEACH",
    "",
    "Ready for Claude Code",
    "Installed to $Destination",
    "",
    "Next: restart Claude Code, finish a build, then run",
    "/teach"
  )
  $ContentWidth = [Math]::Max(54, [int](($ContentLines | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum))
  $Border = "  +" + ("-" * ($ContentWidth + 4)) + "+"

  Write-Host $Border -ForegroundColor DarkGray
  for ($Index = 0; $Index -lt $ContentLines.Count; $Index++) {
    $LineColor = if ($Index -eq 0) {
      "DarkYellow"
    } elseif ($ContentLines[$Index] -eq "/teach") {
      "Cyan"
    } elseif ($ContentLines[$Index] -eq "Ready for Claude Code") {
      "White"
    } else {
      "Gray"
    }
    Write-Host ("  |  " + $ContentLines[$Index].PadRight($ContentWidth) + "  |") -ForegroundColor $LineColor
  }
  Write-Host $Border -ForegroundColor DarkGray
  Write-Host ""
}

Show-TeachSuccess
