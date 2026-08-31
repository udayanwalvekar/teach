$ErrorActionPreference = "Stop"

$TeachInstaller = {
$ErrorActionPreference = "Stop"
$TeachWorker = $env:TEACH_POWERSHELL_WORKER -eq "1"
if ($TeachWorker -and $env:TEACH_POWERSHELL_STATUS_PATH) {
  Set-Content -NoNewline -Path $env:TEACH_POWERSHELL_STATUS_PATH -Value "Detecting coding agents"
} elseif (-not $TeachWorker) {
  Write-Output "Detecting coding agents..."
}

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

function Set-TeachStatus {
  param([Parameter(Mandatory = $true)][string]$Message)
  if ($TeachWorker -and $env:TEACH_POWERSHELL_STATUS_PATH) {
    Set-Content -NoNewline -Path $env:TEACH_POWERSHELL_STATUS_PATH -Value $Message
  } else {
    Write-Output "$Message..."
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

  if ($TeachWorker -and $env:TEACH_POWERSHELL_RESULT_PATH) {
    Set-Content -NoNewline -Path $env:TEACH_POWERSHELL_RESULT_PATH -Value $InstalledFor
    return
  }

  Write-Output "Teach is installed for $InstalledFor. Restart your coding agent, then type: teach"
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

function Write-TeachTuiStep {
  param(
    [Parameter(Mandatory = $true)][int]$StepNumber,
    [Parameter(Mandatory = $true)][int]$PhaseNumber,
    [Parameter(Mandatory = $true)][string]$Frame,
    [Parameter(Mandatory = $true)][string]$Label,
    [bool]$Available = $true
  )

  $Esc = [char]27
  if (-not $Available -and $PhaseNumber -gt 1) {
    Write-Host "$Esc[2K  $Esc[2m–  $($Label.PadRight(31)) not detected$Esc[0m"
  } elseif ($PhaseNumber -gt $StepNumber) {
    Write-Host "$Esc[2K  $Esc[1m✓$Esc[0m  $Label"
  } elseif ($PhaseNumber -eq $StepNumber) {
    Write-Host "$Esc[2K  $Esc[1m$Frame$Esc[0m  $Label"
  } else {
    Write-Host "$Esc[2K  $Esc[2m·  $Label$Esc[0m"
  }
}

function Write-TeachTui {
  param(
    [Parameter(Mandatory = $true)][string]$Phase,
    [Parameter(Mandatory = $true)][string]$Frame,
    [string]$InstalledFor = "",
    [switch]$HasRendered
  )

  $Esc = [char]27
  $PhaseNumber = switch ($Phase) {
    "Detecting coding agents" { 1 }
    "Installing for Codex" { 2 }
    "Installing for Claude Code" { 3 }
    "Finishing" { 4 }
    "Complete" { 5 }
    default { 0 }
  }
  $CodexAvailable = $InstalledFor -ne "Claude Code"
  $ClaudeAvailable = $InstalledFor -ne "Codex"

  if ($HasRendered) {
    Write-Host "$Esc[11A" -NoNewline
  }

  Write-Host "$Esc[2K"
  Write-Host "$Esc[2K  $Esc[1m━━━━━━━━━━$Esc[0m"
  Write-Host "$Esc[2K      ┃  $Esc[1mteach$Esc[0m"
  Write-Host "$Esc[2K      ┃  $Esc[2msetup$Esc[0m"
  Write-Host "$Esc[2K"
  if ($InstalledFor -and $PhaseNumber -gt 1) {
    Write-Host "$Esc[2K  $Esc[1m✓$Esc[0m  $('Detect coding agents'.PadRight(31)) $Esc[2m$InstalledFor$Esc[0m"
  } else {
    Write-TeachTuiStep -StepNumber 1 -PhaseNumber $PhaseNumber -Frame $Frame -Label "Detect coding agents"
  }
  Write-TeachTuiStep -StepNumber 2 -PhaseNumber $PhaseNumber -Frame $Frame -Label "Install Codex" -Available $CodexAvailable
  Write-TeachTuiStep -StepNumber 3 -PhaseNumber $PhaseNumber -Frame $Frame -Label "Install Claude Code" -Available $ClaudeAvailable
  Write-TeachTuiStep -StepNumber 4 -PhaseNumber $PhaseNumber -Frame $Frame -Label "Finish"
  Write-Host "$Esc[2K"
  if ($Phase -eq "Complete") {
    Write-Host "$Esc[2K  $Esc[1mReady.$Esc[0m Restart your coding agent, then type  $Esc[1mteach ↵$Esc[0m"
  } else {
    Write-Host "$Esc[2K  $Esc[2mInstalling Teach…$Esc[0m"
  }
}

function Clear-TeachTui {
  param([switch]$HasRendered)
  if (-not $HasRendered) { return }
  $Esc = [char]27
  Write-Host "$Esc[11A" -NoNewline
  foreach ($Line in 1..11) {
    Write-Host "$Esc[2K"
  }
  Write-Host "$Esc[11A" -NoNewline
}

if (-not (Test-TeachInteractiveTerminal)) {
  & $TeachInstaller
  return
}

$ProgressRoot = Join-Path ([IO.Path]::GetTempPath()) ("teach-progress-" + [guid]::NewGuid().ToString("N"))
$StatusPath = Join-Path $ProgressRoot "status"
$ResultPath = Join-Path $ProgressRoot "result"
$PreviousWorker = $env:TEACH_POWERSHELL_WORKER
$PreviousStatusPath = $env:TEACH_POWERSHELL_STATUS_PATH
$PreviousResultPath = $env:TEACH_POWERSHELL_RESULT_PATH
$PowerShell = $null
$AsyncResult = $null
$Escape = [char]27
$TuiRendered = $false

try {
  New-Item -ItemType Directory -Path $ProgressRoot | Out-Null
  Set-Content -NoNewline -Path $StatusPath -Value "Starting Teach"
  $env:TEACH_POWERSHELL_WORKER = "1"
  $env:TEACH_POWERSHELL_STATUS_PATH = $StatusPath
  $env:TEACH_POWERSHELL_RESULT_PATH = $ResultPath

  $PowerShell = [PowerShell]::Create()
  $PowerShell.AddScript($TeachInstaller.ToString()) | Out-Null
  Write-Host "$Escape[?25l" -NoNewline
  $AsyncResult = $PowerShell.BeginInvoke()
  $Frames = @("⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏")
  $FrameIndex = 0

  while (-not $AsyncResult.IsCompleted) {
    $Status = try { [IO.File]::ReadAllText($StatusPath) } catch { "Starting Teach" }
    if (-not $Status) { $Status = "Starting Teach" }
    $InstalledFor = if (Test-Path -LiteralPath $ResultPath) {
      try { [IO.File]::ReadAllText($ResultPath) } catch { "" }
    } else { "" }
    $Frame = $Frames[$FrameIndex % $Frames.Count]
    $FrameIndex++
    Write-TeachTui -Phase $Status -Frame $Frame -InstalledFor $InstalledFor -HasRendered:$TuiRendered
    $TuiRendered = $true
    Start-Sleep -Milliseconds 80
  }

  $null = $PowerShell.EndInvoke($AsyncResult)
  if ($PowerShell.HadErrors) {
    $Failure = ($PowerShell.Streams.Error | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
    throw $Failure
  }

  $InstalledFor = [IO.File]::ReadAllText($ResultPath)
  Write-TeachTui -Phase "Complete" -Frame "✓" -InstalledFor $InstalledFor -HasRendered:$TuiRendered
  $TuiRendered = $true
  Write-Host "$Escape[?25h" -NoNewline
}
catch {
  Clear-TeachTui -HasRendered:$TuiRendered
  Write-Host "$Escape[?25h" -NoNewline
  throw "Teach could not be installed.`n$($_.Exception.Message)"
}
finally {
  Write-Host "$Escape[?25h" -NoNewline
  if ($PowerShell) {
    if ($AsyncResult -and -not $AsyncResult.IsCompleted) { $PowerShell.Stop() }
    $PowerShell.Dispose()
  }
  $env:TEACH_POWERSHELL_WORKER = $PreviousWorker
  $env:TEACH_POWERSHELL_STATUS_PATH = $PreviousStatusPath
  $env:TEACH_POWERSHELL_RESULT_PATH = $PreviousResultPath
  if (Test-Path -LiteralPath $ProgressRoot) {
    Remove-Item -Recurse -Force -LiteralPath $ProgressRoot
  }
}
