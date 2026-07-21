<#
Reassembles releases/windows/cttc-windows-deploy.zip.partNNN chunks (split
so no single file exceeds GitHub's 100MB blob limit) back into the real
cttc-windows-deploy.zip, extracts it, stages the server image tarball where
CTTC looks for an offline image (see app/lib/server-provision.js), installs
CTTC itself, then cleans up everything only needed to get there -- the
chunks, the reassembled zip, the extraction folder, the build-image/ build
scripts, and (if the OS allows deleting a running script) this file itself.

Usage: from a PowerShell prompt, in the same directory as the chunks:
  powershell -ExecutionPolicy Bypass -File .\prepare-image.ps1

From here on, CTTC's own first-run logic takes over (see
releases/windows/README.md's "How this all fits together"): it looks for
the staged tarball and `docker load`s it -- locally if Docker is present,
or on a Docker-enabled host over SSH (via its setup wizard) otherwise.
Nothing needs to be run manually beyond this script.
#>

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$zipName = "cttc-windows-deploy.zip"
$zipPath = Join-Path $root $zipName
$extractDir = Join-Path $root "cttc-windows-deploy"
$offlineImageDir = Join-Path $env:USERPROFILE ".cttc\offline-image"

function Fail($msg) {
  Write-Host ""
  Write-Host "ERROR: $msg" -ForegroundColor Red
  Write-Host ""
  Read-Host "Press Enter to close"
  exit 1
}

$parts = Get-ChildItem -Path $root -Filter "$zipName.part*" | Sort-Object Name
if ($parts.Count -eq 0) {
  Fail "no $zipName.partNNN chunks found next to this script."
}
Write-Host "Reassembling $($parts.Count) chunk(s) into $zipName ..." -ForegroundColor Cyan

if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
$out = [System.IO.File]::Open($zipPath, [System.IO.FileMode]::CreateNew)
try {
  foreach ($part in $parts) {
    Write-Host "  + $($part.Name)"
    $in = [System.IO.File]::OpenRead($part.FullName)
    try { $in.CopyTo($out) } finally { $in.Close() }
  }
} finally {
  $out.Close()
}
Write-Host "Wrote $zipPath ($([Math]::Round((Get-Item $zipPath).Length / 1MB, 1)) MB)"

Write-Host "Extracting to $extractDir ..." -ForegroundColor Cyan
if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
Expand-Archive -Path $zipPath -DestinationPath $extractDir

# -- stage the offline image where CTTC's first-run logic looks for it -----
Write-Host "Staging the server image for CTTC's first run..." -ForegroundColor Cyan
New-Item -ItemType Directory -Force -Path $offlineImageDir | Out-Null
Copy-Item (Join-Path $extractDir "image\cttc-server.tar.gz") (Join-Path $offlineImageDir "cttc-server.tar.gz") -Force
Copy-Item (Join-Path $extractDir "image\docker-compose.yml") (Join-Path $offlineImageDir "docker-compose.yml") -Force
Write-Host "Staged at $offlineImageDir"

# -- install the real client (no Node/npm on this machine at all) -----------
$installerPath = Join-Path $extractDir "CTTC Setup.exe"
if (-not (Test-Path $installerPath)) { Fail "Installer not found at '$installerPath' -- the bundle may be incomplete." }
Write-Host ""
Write-Host "Installing CTTC..." -ForegroundColor Cyan
$proc = Start-Process -FilePath $installerPath -ArgumentList "/S" -Wait -PassThru
if ($proc.ExitCode -ne 0) { Fail "CTTC installer exited with code $($proc.ExitCode)." }

Write-Host "Cleaning up build artifacts..." -ForegroundColor Cyan
Remove-Item $zipPath -Force
Remove-Item $parts.FullName -Force
Remove-Item $extractDir -Recurse -Force
$buildImageDir = Join-Path $root "build-image"
if (Test-Path $buildImageDir) { Remove-Item $buildImageDir -Recurse -Force }

# -- launch it ----------------------------------------------------------------
# The installer creates fixed shortcut locations regardless of the (optional,
# user-selectable) install directory, so launch via the Start Menu shortcut
# rather than guessing where CTTC.exe ended up.
$shortcut = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\CTTC.lnk"
if (-not (Test-Path $shortcut)) { Fail "Install finished but shortcut not found at $shortcut." }
Write-Host ""
Write-Host "Starting CTTC -- it will load the staged image on its own (locally, or on a" -ForegroundColor Cyan
Write-Host "Docker-enabled host over SSH if you don't have Docker here)..." -ForegroundColor Cyan
Start-Process -FilePath $shortcut

Write-Host ""
Write-Host "Done." -ForegroundColor Green

# Best-effort self-delete -- PowerShell doesn't hold an exclusive lock on a
# running .ps1, so this succeeds on Windows/PowerShell 7+ in practice, but
# isn't guaranteed on every OS/filesystem, hence -ErrorAction SilentlyContinue.
Remove-Item -LiteralPath $PSCommandPath -Force -ErrorAction SilentlyContinue
