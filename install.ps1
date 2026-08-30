$ErrorActionPreference = "Stop"

$SourceBaseUrl = if ($env:TEACH_SOURCE_BASE_URL) {
  $env:TEACH_SOURCE_BASE_URL.TrimEnd("/")
} else {
  $Resolution = Invoke-RestMethod -UseBasicParsing -Uri "https://data.jsdelivr.com/v1/package/resolve/gh/udayanwalvekar/teach@latest"
  $ResolvedVersion = [string]$Resolution.version
  $SemVerPattern = "^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$"
  if (-not $ResolvedVersion -or $ResolvedVersion -notmatch $SemVerPattern) {
    throw "jsDelivr returned an invalid Teach release version: $ResolvedVersion"
  }
  "https://cdn.jsdelivr.net/gh/udayanwalvekar/teach@v$ResolvedVersion"
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

  Invoke-WebRequest -UseBasicParsing -Uri "$SourceBaseUrl/claude-files.txt" -OutFile $ManifestPath
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
    Invoke-WebRequest -UseBasicParsing -Uri (Get-TeachDownloadUrl -RelativePath $RelativePath) -OutFile $TargetPath
  }

  $InstallerPath = Join-Path $SourceRoot "install-claude.ps1"
  if (-not (Test-Path -LiteralPath $InstallerPath -PathType Leaf)) {
    throw "The Teach manifest did not provide install-claude.ps1."
  }

  if (Test-Path -LiteralPath $Destination) {
    & $InstallerPath -Force
  } else {
    & $InstallerPath
  }
  if (-not $?) {
    throw "The Teach installer did not complete successfully."
  }
}
finally {
  if (Test-Path -LiteralPath $DownloadRoot) {
    Remove-Item -Recurse -Force -LiteralPath $DownloadRoot
  }
}
