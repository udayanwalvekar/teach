$ErrorActionPreference = "Stop"

$CodexDetected = $null -ne (Get-Command codex -ErrorAction SilentlyContinue)
$ClaudeDetected = ($null -ne (Get-Command claude -ErrorAction SilentlyContinue)) -or (Test-Path (Join-Path $HOME ".claude"))

if (-not $CodexDetected -and -not $ClaudeDetected) {
  throw "Teach could not find Codex or Claude Code on this computer. Install one, then run this same command again."
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

function Assert-TeachCommandSucceeded {
  param([Parameter(Mandatory = $true)][string]$Action)
  if ($LASTEXITCODE -ne 0) {
    throw "Teach could not complete: $Action"
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

$TeachInteractive = Test-TeachInteractiveTerminal
$TeachFrameIndex = 0
$TeachFrames = @("⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏")

function Set-TeachStatus {
  param([Parameter(Mandatory = $true)][string]$Message)
  if ($TeachInteractive) {
    $Frame = $TeachFrames[$TeachFrameIndex % $TeachFrames.Count]
    $script:TeachFrameIndex++
    Write-Host "`r$(' ' * 72)`r  $Frame  $Message" -NoNewline -ForegroundColor White
  } else {
    Write-Output "$Message..."
  }
}

function Complete-TeachStatus {
  if ($TeachInteractive) {
    Write-Host "`r$(' ' * 72)`r" -NoNewline
  }
}

function Show-TeachReady {
  $InstalledFor = if ($CodexDetected -and $ClaudeDetected) {
    "Codex + Claude Code"
  } elseif ($CodexDetected) {
    "Codex"
  } else {
    "Claude Code"
  }

  Complete-TeachStatus
  if (-not $TeachInteractive) {
    Write-Output "Teach is installed for $InstalledFor. Restart your coding agent, then type: teach"
    return
  }

  Write-Host ""
  Write-Host "  ✓ Teach installed" -ForegroundColor White
  Write-Host "    $InstalledFor" -ForegroundColor Gray
  Write-Host ""
  Write-Host "    Restart your coding agent, then type: " -NoNewline -ForegroundColor Gray
  Write-Host "teach" -ForegroundColor White
  Write-Host ""
}

if ($CodexDetected) {
  Set-TeachStatus "Installing for Codex"
  $MarketplaceData = (& codex plugin marketplace list --json | Out-String | ConvertFrom-Json)
  if ($MarketplaceData.marketplaces | Where-Object { $_.name -eq "teach" }) {
    & codex plugin marketplace upgrade teach | Out-Null
    Assert-TeachCommandSucceeded "refresh the Codex marketplace"
  } else {
    & codex plugin marketplace add udayanwalvekar/teach | Out-Null
    Assert-TeachCommandSucceeded "add the Codex marketplace"
  }

  $PluginData = (& codex plugin list --json | Out-String | ConvertFrom-Json)
  if ($PluginData.installed | Where-Object { $_.pluginId -eq "teach@teach" -and $_.installed }) {
    & codex plugin remove teach@teach | Out-Null
    Assert-TeachCommandSucceeded "replace the existing Codex plugin"
  }
  & codex plugin add teach@teach | Out-Null
  Assert-TeachCommandSucceeded "install the Codex plugin"

  $MarketplaceData = (& codex plugin marketplace list --json | Out-String | ConvertFrom-Json)
  $CodexMarketplaceRoot = ($MarketplaceData.marketplaces | Where-Object { $_.name -eq "teach" } | Select-Object -First 1).root
}

if (-not $ClaudeDetected) {
  Set-TeachStatus "Finishing"
  Show-TeachReady
  return
}

Set-TeachStatus "Installing for Claude Code"

$LocalSourceRoot = $null
$SourceBaseUrl = if ($env:TEACH_SOURCE_BASE_URL) {
  $env:TEACH_SOURCE_BASE_URL.TrimEnd("/")
} elseif ($CodexMarketplaceRoot -and (Test-Path -LiteralPath (Join-Path $CodexMarketplaceRoot "claude-files.txt") -PathType Leaf)) {
  $LocalSourceRoot = $CodexMarketplaceRoot
  $null
} else {
  $Release = Invoke-RestMethod -UseBasicParsing -Uri "https://api.github.com/repos/udayanwalvekar/teach/releases/latest"
  $TeachRelease = [string]$Release.tag_name
  if ($TeachRelease -notmatch "^v[0-9]+\.[0-9]+\.[0-9]+(?:[-+][0-9A-Za-z.-]+)?$") {
    throw "GitHub returned an invalid Teach release: $TeachRelease"
  }
  "https://raw.githubusercontent.com/udayanwalvekar/teach/$TeachRelease"
}
$Destination = if ($env:TEACH_CLAUDE_DESTINATION) {
  $env:TEACH_CLAUDE_DESTINATION
} else {
  Join-Path $HOME ".claude/skills/teach"
}
$DownloadRoot = Join-Path ([IO.Path]::GetTempPath()) ("teach-download-" + [guid]::NewGuid().ToString("N"))
$SourceRoot = Join-Path $DownloadRoot "source"
$ManifestPath = Join-Path $DownloadRoot "claude-files.txt"

function Get-TeachDownloadUrl {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RelativePath
  )

  $EncodedPath = (($RelativePath -split "/") | ForEach-Object {
    [Uri]::EscapeDataString($_)
  }) -join "/"
  return "$SourceBaseUrl/$EncodedPath"
}

function Resolve-TeachSourcePath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$RelativePath
  )

  if (
    [IO.Path]::IsPathRooted($RelativePath) -or
    $RelativePath.Contains("\") -or
    $RelativePath -notmatch "^[A-Za-z0-9._/-]+$"
  ) {
    throw "The Teach manifest contains an invalid relative path: $RelativePath"
  }

  $Segments = @($RelativePath -split "/")
  if ($Segments.Count -eq 0 -or $Segments -contains "" -or $Segments -contains "." -or $Segments -contains "..") {
    throw "The Teach manifest contains an invalid relative path: $RelativePath"
  }

  $SourceRootFullPath = [IO.Path]::GetFullPath($SourceRoot).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
  $TargetPath = [IO.Path]::GetFullPath((Join-Path $SourceRoot ($RelativePath.Replace("/", [IO.Path]::DirectorySeparatorChar))))
  if (-not $TargetPath.StartsWith($SourceRootFullPath, [StringComparison]::OrdinalIgnoreCase)) {
    throw "The Teach manifest path escapes the temporary source directory: $RelativePath"
  }

  return $TargetPath
}

try {
  New-Item -ItemType Directory -Path $SourceRoot | Out-Null

  if ($LocalSourceRoot) {
    Copy-Item -LiteralPath (Join-Path $LocalSourceRoot "claude-files.txt") -Destination $ManifestPath
  } else {
    Invoke-WebRequest -UseBasicParsing -Uri "$SourceBaseUrl/claude-files.txt" -OutFile $ManifestPath
  }
  $ManifestEntries = @(Get-Content -Path $ManifestPath | ForEach-Object { $_.Trim() } | Where-Object {
    $_ -and -not $_.StartsWith("#")
  })
  if ($ManifestEntries.Count -eq 0) {
    throw "The Teach Claude file manifest is empty."
  }

  foreach ($RelativePath in $ManifestEntries) {
    $TargetPath = Resolve-TeachSourcePath -RelativePath $RelativePath
    $TargetParent = Split-Path -Parent $TargetPath
    New-Item -ItemType Directory -Force -Path $TargetParent | Out-Null
    if ($LocalSourceRoot) {
      $LocalSourcePath = Join-Path $LocalSourceRoot ($RelativePath.Replace("/", [IO.Path]::DirectorySeparatorChar))
      if (-not (Test-Path -LiteralPath $LocalSourcePath -PathType Leaf)) {
        throw "The Teach marketplace is missing: $RelativePath"
      }
      Copy-Item -LiteralPath $LocalSourcePath -Destination $TargetPath
    } else {
      Invoke-WebRequest -UseBasicParsing -Uri (Get-TeachDownloadUrl -RelativePath $RelativePath) -OutFile $TargetPath
    }
  }

  $InstallerPath = Join-Path $SourceRoot "install-claude.ps1"
  if (-not (Test-Path -LiteralPath $InstallerPath -PathType Leaf)) {
    throw "The Teach manifest did not provide install-claude.ps1."
  }

  $PreviousQuietInstall = $env:TEACH_QUIET_INSTALL
  $env:TEACH_QUIET_INSTALL = "1"
  $InstallerSucceeded = $false
  try {
    if (Test-Path -LiteralPath $Destination) {
      & $InstallerPath -Force
    } else {
      & $InstallerPath
    }
    $InstallerSucceeded = $? -and $LASTEXITCODE -eq 0
  }
  finally {
    $env:TEACH_QUIET_INSTALL = $PreviousQuietInstall
  }
  if (-not $InstallerSucceeded) {
    throw "The Teach installer did not complete successfully."
  }
}
finally {
  if (Test-Path -LiteralPath $DownloadRoot) {
    Remove-Item -Recurse -Force -LiteralPath $DownloadRoot
  }
}

Set-TeachStatus "Finishing"
Show-TeachReady
