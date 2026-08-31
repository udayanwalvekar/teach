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
  $SkillText += "`n`n## Builder request`n`n`$ARGUMENTS`n"
  [IO.File]::WriteAllText(
    (Join-Path $StagedSkill "SKILL.md"),
    $SkillText,
    [Text.UTF8Encoding]::new($false)
  )

  foreach ($ResourceDir in @("assets", "examples", "references", "runtime", "scripts")) {
    $ResourceSource = Join-Path $SourceDir $ResourceDir
    if (Test-Path $ResourceSource -PathType Container) {
      Copy-Item -Recurse -Path $ResourceSource -Destination (Join-Path $StagedSkill $ResourceDir)
    }
  }

  if (Test-Path $Destination) {
    $Backup = "$Destination.backup-$([DateTime]::UtcNow.ToString('yyyyMMddHHmmss'))-$([guid]::NewGuid().ToString('N').Substring(0, 8))"
    Move-Item -Path $Destination -Destination $Backup
    if (-not $env:TEACH_QUIET_INSTALL) {
      Write-Host "Backed up the previous Teach skill to $Backup"
    }
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
  if ($env:TEACH_QUIET_INSTALL) {
    return
  }

  if (-not (Test-TeachInteractiveTerminal)) {
    Write-Output "Teach is installed for Claude Code. Restart Claude Code, then type: teach"
    return
  }

  Write-Host ""
  Write-Host "  ✓ Teach installed" -ForegroundColor White
  Write-Host "    Claude Code" -ForegroundColor Gray
  Write-Host ""
  Write-Host "    Restart Claude Code, then type: " -NoNewline -ForegroundColor Gray
  Write-Host "teach" -ForegroundColor White
  Write-Host ""
}

Show-TeachSuccess
