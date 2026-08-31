$ErrorActionPreference = "Stop"

$Resolver = Join-Path $PSScriptRoot "resolve_runtime.py"
$Candidates = @(
  @{ Command = "py"; Prefix = @("-3") },
  @{ Command = "python3"; Prefix = @() },
  @{ Command = "python"; Prefix = @() }
)

foreach ($Candidate in $Candidates) {
  if (-not (Get-Command $Candidate.Command -ErrorAction SilentlyContinue)) {
    continue
  }

  $VersionArguments = @($Candidate.Prefix) + @(
    "-c",
    "import sys; raise SystemExit(sys.version_info < (3, 9))"
  )
  & $Candidate.Command $VersionArguments 2>$null
  if ($LASTEXITCODE -ne 0) {
    continue
  }

  $ResolverArguments = @($Candidate.Prefix) + @($Resolver)
  & $Candidate.Command $ResolverArguments
  if ($LASTEXITCODE -ne 0) {
    throw "Teach could not resolve its current prompt."
  }
  return
}

throw "Teach needs Python 3.9 or newer. Install Python 3, then run Teach again."
