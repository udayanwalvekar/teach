$ErrorActionPreference = "Stop"

$Repo = Split-Path -Parent $PSScriptRoot
$TestRoot = Join-Path ([IO.Path]::GetTempPath()) ("teach-installer-test-" + [guid]::NewGuid().ToString("N"))
$TestHome = Join-Path $TestRoot "home"
$State = Join-Path $TestRoot "state"
$Actions = Join-Path $State "actions"
$CurlLog = Join-Path $State "downloads"
New-Item -ItemType Directory -Path $TestHome, $State | Out-Null
New-Item -ItemType Directory -Path (Join-Path $TestHome ".claude") | Out-Null
New-Item -ItemType File -Path $CurlLog | Out-Null

$OriginalHome = $env:HOME
$OriginalUserProfile = $env:USERPROFILE
$env:HOME = $TestHome
$env:USERPROFILE = $TestHome

function global:codex {
  $CommandLine = $args -join " "
  Add-Content -Path $Actions -Value $CommandLine
  $global:LASTEXITCODE = 0

  if ($env:TEACH_TEST_FAIL_ACTION -and $CommandLine -eq $env:TEACH_TEST_FAIL_ACTION) {
    $global:LASTEXITCODE = 1
    return
  }

  switch ($CommandLine) {
    "plugin marketplace list --json" {
      $Marketplaces = if (Test-Path (Join-Path $State "marketplace")) {
        @(@{ name = "teach"; root = $Repo })
      } else {
        @()
      }
      @{ marketplaces = $Marketplaces } | ConvertTo-Json -Depth 4 -Compress
    }
    "plugin marketplace add udayanwalvekar/teach" {
      New-Item -ItemType File -Force -Path (Join-Path $State "marketplace") | Out-Null
    }
    "plugin marketplace upgrade teach" {
      if (-not (Test-Path (Join-Path $State "marketplace"))) { $global:LASTEXITCODE = 1 }
    }
    "plugin list --json" {
      $Installed = if (Test-Path (Join-Path $State "plugin")) {
        @(@{ pluginId = "teach@teach"; installed = $true })
      } else {
        @()
      }
      @{ installed = $Installed } | ConvertTo-Json -Depth 4 -Compress
    }
    "plugin add teach@teach" {
      New-Item -ItemType File -Force -Path (Join-Path $State "plugin") | Out-Null
    }
    "plugin remove teach@teach" {
      Remove-Item -Force -Path (Join-Path $State "plugin")
    }
    default {
      throw "Unexpected fake Codex command: $CommandLine"
    }
  }
}

function global:Invoke-WebRequest {
  param(
    [switch]$UseBasicParsing,
    [Parameter(Mandatory = $true)][string]$Uri,
    [Parameter(Mandatory = $true)][string]$OutFile
  )
  Add-Content -Path $CurlLog -Value $Uri
  $Prefix = "https://raw.githubusercontent.com/udayanwalvekar/teach/"
  if (-not $Uri.StartsWith($Prefix)) {
    throw "Unexpected fake download URL: $Uri"
  }
  $RevisionAndPath = $Uri.Substring($Prefix.Length)
  $Slash = $RevisionAndPath.IndexOf("/")
  $RelativePath = $RevisionAndPath.Substring($Slash + 1)
  Copy-Item -Path (Join-Path $Repo $RelativePath) -Destination $OutFile
}

try {
  & (Join-Path $Repo "install.ps1")
  & (Join-Path $Repo "install.ps1")

  if (-not (Test-Path (Join-Path $TestHome ".claude/skills/teach/SKILL.md"))) {
    throw "Claude skill was not installed."
  }
  foreach ($RelativePath in @(
    "runtime/manifest.json",
    "runtime/teach.md",
    "scripts/resolve_runtime.py",
    "scripts/resolve_runtime.ps1",
    "scripts/resolve_runtime.sh"
  )) {
    if (-not (Test-Path (Join-Path $TestHome ".claude/skills/teach/$RelativePath"))) {
      throw "Claude install is missing the dynamic prompt file: $RelativePath"
    }
  }
  if (Select-String -Quiet -SimpleMatch "disable-model-invocation: true" (Join-Path $TestHome ".claude/skills/teach/SKILL.md")) {
    throw "Claude install still disables bare teach invocation."
  }
  if (-not (Select-String -Quiet -SimpleMatch '${CLAUDE_SKILL_DIR}' (Join-Path $TestHome ".claude/skills/teach/SKILL.md"))) {
    throw "Claude install does not map its concrete skill directory."
  }

  $PreviousDisableUpdates = $env:TEACH_DISABLE_UPDATES
  $env:TEACH_DISABLE_UPDATES = "1"
  try {
    $InstalledResolver = Join-Path $TestHome ".claude/skills/teach/scripts/resolve_runtime.ps1"
    $InstalledRuntime = (& $InstalledResolver | Out-String).Trim()
  }
  finally {
    $env:TEACH_DISABLE_UPDATES = $PreviousDisableUpdates
  }
  $ExpectedRuntime = (Resolve-Path (Join-Path $TestHome ".claude/skills/teach/runtime/teach.md")).Path
  if ($InstalledRuntime -ne $ExpectedRuntime) {
    throw "Installed PowerShell resolver did not select the bundled prompt."
  }

  $ActionLines = @(Get-Content $Actions)
  if (@($ActionLines | Where-Object { $_ -eq "plugin marketplace add udayanwalvekar/teach" }).Count -ne 1) {
    throw "Codex marketplace should be added exactly once."
  }
  if (@($ActionLines | Where-Object { $_ -eq "plugin marketplace upgrade teach" }).Count -ne 1) {
    throw "Codex marketplace should be upgraded exactly once."
  }
  if (@(Get-ChildItem (Join-Path $TestHome ".claude/skills") -Directory -Filter "teach.backup-*").Count -ne 1) {
    throw "Claude update should create exactly one backup."
  }

  if ((Get-Item $CurlLog).Length -ne 0) {
    throw "Combined install should reuse the refreshed local Codex marketplace for Claude."
  }

  $env:TEACH_TEST_FAIL_ACTION = "plugin marketplace upgrade teach"
  $FailedAsExpected = $false
  try {
    & (Join-Path $Repo "install.ps1")
  }
  catch {
    $FailedAsExpected = $true
  }
  if (-not $FailedAsExpected) {
    throw "Codex command failure was not propagated."
  }

  Write-Output "PowerShell universal installer checks passed."
}
finally {
  Remove-Item Env:TEACH_TEST_FAIL_ACTION -ErrorAction SilentlyContinue
  $env:HOME = $OriginalHome
  $env:USERPROFILE = $OriginalUserProfile
  Remove-Item -Recurse -Force -Path $TestRoot -ErrorAction SilentlyContinue
  Remove-Item Function:codex -ErrorAction SilentlyContinue
  Remove-Item Function:Invoke-WebRequest -ErrorAction SilentlyContinue
}
