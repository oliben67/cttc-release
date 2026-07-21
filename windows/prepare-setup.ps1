<#
If "CTTC Setup.exe" is already sitting next to this script (small enough to
commit directly -- see releases/shared/finalize-artifact.sh), there's
nothing to do. Otherwise reassembles releases/windows/cttc-windows-deploy.zip.partNNN
chunks (split so no single file exceeds GitHub's 100MB blob limit) back
into the real cttc-windows-deploy.zip, extracts it, then cleans up
everything only needed to get there -- the chunks, the reassembled zip,
and (if the OS allows deleting a running script) this file itself --
leaving just "CTTC Setup.exe" behind.

This script does NOT install or run anything. That's deliberate: no
PowerShell beyond this one script is ever used -- run "CTTC Setup.exe"
yourself, the same as any other Windows installer. From there CTTC handles
everything itself: the server image is already baked into the installer
(or, for a "slim" build, just a registry reference -- see
app/lib/server-provision.js), so there's no separate staging or deploy
step left to run.

Usage: from a PowerShell prompt, in the same directory as this script:
  powershell -ExecutionPolicy Bypass -File .\prepare-setup.ps1
#>

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$zipName = "cttc-windows-deploy.zip"
$zipPath = Join-Path $root $zipName
$installerPath = Join-Path $root "CTTC Setup.exe"

if (Test-Path $installerPath) {
  Write-Host "'$installerPath' is already here -- nothing to reassemble. Run it to install." -ForegroundColor Green
  Remove-Item -LiteralPath $PSCommandPath -Force -ErrorAction SilentlyContinue
  exit 0
}

$parts = Get-ChildItem -Path $root -Filter "$zipName.part*" | Sort-Object Name
if ($parts.Count -eq 0) {
  Write-Host "ERROR: no '$installerPath' and no $zipName.partNNN chunks found next to this script." -ForegroundColor Red
  exit 1
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

# The zip contains just the one file (CTTC Setup.exe) -- extract straight
# into this directory instead of a nested "cttc-windows-deploy\" folder.
Write-Host "Extracting to $root ..." -ForegroundColor Cyan
Expand-Archive -Path $zipPath -DestinationPath $root

Write-Host "Cleaning up build artifacts..." -ForegroundColor Cyan
Remove-Item $zipPath -Force
Remove-Item $parts.FullName -Force

Write-Host ""
Write-Host "Done. Run '$installerPath' to install." -ForegroundColor Green

# Best-effort self-delete -- PowerShell doesn't hold an exclusive lock on a
# running .ps1, so this succeeds on Windows/PowerShell 7+ in practice, but
# isn't guaranteed on every OS/filesystem, hence -ErrorAction SilentlyContinue.
Remove-Item -LiteralPath $PSCommandPath -Force -ErrorAction SilentlyContinue
