param(
  [switch]$Tailscale
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

function Require-Command([string]$Name, [string]$InstallHint) {
  if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
    throw "$Name is required. $InstallHint"
  }
}

Require-Command "node" "Install Node.js 20 or newer, then open a new PowerShell window."
Require-Command "uv" "Install uv, then open a new PowerShell window."

$venvPath = Join-Path $projectRoot ".venv"
$pythonPath = Join-Path $venvPath "Scripts\python.exe"

if (-not (Test-Path -LiteralPath $pythonPath)) {
  Write-Host "Creating the MeterMesh Python environment..."
  & uv python install 3.12
  if ($LASTEXITCODE -ne 0) { throw "uv could not install Python 3.12." }
  & uv venv --python 3.12 $venvPath
  if ($LASTEXITCODE -ne 0) { throw "uv could not create .venv." }
}

$env:PYTHON = $pythonPath

Write-Host "Checking Python dependencies..."
& uv pip install --python $pythonPath --quiet -r (Join-Path $projectRoot "requirements.txt")
if ($LASTEXITCODE -ne 0) { throw "uv could not install MeterMesh Python dependencies." }

if (-not (Test-Path -LiteralPath (Join-Path $projectRoot "node_modules"))) {
  Write-Host "Installing frontend dependencies..."
  & npm install
  if ($LASTEXITCODE -ne 0) { throw "npm install failed." }
}

if ($Tailscale) {
  Require-Command "tailscale" "Install Tailscale, then open a new PowerShell window."
  & tailscale serve --bg 8765
  if ($LASTEXITCODE -ne 0) { throw "Could not configure Tailscale Serve." }

  $serveStatus = (& tailscale serve status 2>$null | Out-String)
  if ($serveStatus -match "https://(?<tailscaleHost>[^/\s]+)") {
    # Vite rejects unknown Host headers by default. Allow only this machine's
    # current Tailscale DNS name, avoiding the unsafe allowedHosts=true mode.
    $env:__VITE_ADDITIONAL_SERVER_ALLOWED_HOSTS = $Matches.tailscaleHost
  } elseif (-not $env:__VITE_ADDITIONAL_SERVER_ALLOWED_HOSTS) {
    throw "Could not determine the Tailscale hostname. Run 'tailscale serve status' and set __VITE_ADDITIONAL_SERVER_ALLOWED_HOSTS, then retry."
  }
  Write-Host "Tailscale Serve configured. Run 'tailscale serve status' to get the iPhone URL."
}

Write-Host "Starting MeterMesh at http://127.0.0.1:8765"
& npm run dev:all
exit $LASTEXITCODE
