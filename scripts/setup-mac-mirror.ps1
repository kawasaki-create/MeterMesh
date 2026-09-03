# Creates the add_stat/mac-mirror manifest + root folders MeterMesh needs to
# treat a Syncthing-fed copy of another machine's Codex/Claude/OpenCode data as
# a continuously rescanned source. See README.md, "Combining usage from a
# second machine". Safe to re-run: existing manifests and folders are left
# untouched.

$ErrorActionPreference = "Stop"

function New-MirrorManifest([string]$Provider, [string]$Root, [string]$RelativeInsideRoot) {
  $mirrorDir = Join-Path $Root "add_stat\mac-mirror"
  $dataDir = Join-Path $mirrorDir (Join-Path "root" $RelativeInsideRoot)
  New-Item -ItemType Directory -Force -Path $dataDir | Out-Null

  $manifestPath = Join-Path $mirrorDir "snapshot.json"
  if (Test-Path -LiteralPath $manifestPath) {
    Write-Host "Already set up: $manifestPath"
    return
  }

  $manifest = [ordered]@{
    format     = "metermesh-provider-snapshot"
    version    = 1
    id         = "mac-mirror-$Provider"
    provider   = $Provider
    created_at = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    label      = "Mac (Syncthing mirror)"
    root       = "root"
    refresh    = "continuous"
  }
  ($manifest | ConvertTo-Json) | Out-File -LiteralPath $manifestPath -Encoding utf8
  Write-Host "Created $manifestPath"
  Write-Host "  Point Syncthing (send-only on the Mac) at: $dataDir"
}

$codexRoot = if ($env:CODEX_USAGE_DB) { Split-Path -Parent $env:CODEX_USAGE_DB } else { Join-Path $HOME ".codex" }
$claudeRoot = if ($env:CLAUDE_PROJECTS_DIR) { Split-Path -Parent $env:CLAUDE_PROJECTS_DIR } else { Join-Path $HOME ".claude" }
$opencodeRoot = if ($env:OPENCODE_USAGE_DB) {
  Split-Path -Parent $env:OPENCODE_USAGE_DB
} elseif ($env:XDG_DATA_HOME) {
  Join-Path $env:XDG_DATA_HOME "opencode"
} else {
  Join-Path $HOME ".local\share\opencode"
}

New-MirrorManifest -Provider "codex" -Root $codexRoot -RelativeInsideRoot "sessions"
New-MirrorManifest -Provider "claude" -Root $claudeRoot -RelativeInsideRoot "projects"
New-MirrorManifest -Provider "opencode" -Root $opencodeRoot -RelativeInsideRoot ""

Write-Host ""
Write-Host "Done. Restart MeterMesh, then enable each new 'Mirror' source in Settings > Data Health."
