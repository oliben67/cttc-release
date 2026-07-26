<#
If "CTTC Setup.exe" is already sitting next to this script (small enough to
commit directly -- see releases/_shared/finalize-artifact.sh), skips
straight to launching it. Otherwise reassembles
releases/windows/cttc-windows-deploy.zip.partNNN chunks (split so no
single file exceeds GitHub's 100MB blob limit) back into the real
cttc-windows-deploy.zip, extracts it, cleans up everything only needed to
get there -- the chunks and the reassembled zip -- then launches
"CTTC Setup.exe", and (if the OS allows deleting a running script) deletes
itself.

No PowerShell beyond this one script is ever used. From "CTTC Setup.exe"
onward, CTTC handles everything itself: the server image is already baked
into the installer (or, for a "slim" build, just a registry reference --
see app/lib/server-provision.js), so there's no separate staging or
deploy step left to run.

Usage: from a PowerShell prompt, in the same directory as this script:
  powershell -ExecutionPolicy Bypass -File ".\CTTC Setup.ps1"
#>

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$zipName = "cttc-windows-deploy.zip"
$zipPath = Join-Path $root $zipName
$installerPath = Join-Path $root "CTTC Setup.exe"

function Launch-Installer {
  Write-Host "Starting '$installerPath' ..." -ForegroundColor Cyan
  try {
    Start-Process -FilePath $installerPath -ErrorAction Stop
  } catch {
    # Don't let a launch failure (e.g. blocked by AV, already running) abort
    # cleanup/self-delete below -- the installer is still sitting right
    # there either way, just tell the user to double-click it themselves.
    Write-Host "Could not start it automatically ($($_.Exception.Message)) -- double-click '$installerPath' to install." -ForegroundColor Yellow
  }
}

if (Test-Path $installerPath) {
  Write-Host "'$installerPath' is already here -- nothing to reassemble." -ForegroundColor Green
  Launch-Installer
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
Launch-Installer

# Best-effort self-delete -- PowerShell doesn't hold an exclusive lock on a
# running .ps1, so this succeeds on Windows/PowerShell 7+ in practice, but
# isn't guaranteed on every OS/filesystem, hence -ErrorAction SilentlyContinue.
Remove-Item -LiteralPath $PSCommandPath -Force -ErrorAction SilentlyContinue
