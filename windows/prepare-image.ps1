<#
Reassembles releases/windows/cttc-windows-deploy.zip.partNNN chunks (split
so no single file exceeds GitHub's 100MB blob limit) back into the real
cttc-windows-deploy.zip, extracts it next to this script, then cleans up
everything that was only needed to get there -- the chunks, the
reassembled zip, the src/ build scripts, and (if the OS allows deleting a
running script) this file itself -- leaving just the extracted deployment
bundle behind.

Usage: from a PowerShell prompt, in the same directory as the chunks:
  powershell -ExecutionPolicy Bypass -File .\prepare-image.ps1

Run this once after cloning/pulling; it produces the actual deployment
bundle (CTTC Setup.exe, image/, keys/, deploy.ps1, README-WINDOWS.md) in a
sibling "cttc-windows-deploy" folder.
#>

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$zipName = "cttc-windows-deploy.zip"
$zipPath = Join-Path $root $zipName
$extractDir = Join-Path $root "cttc-windows-deploy"

$parts = Get-ChildItem -Path $root -Filter "$zipName.part*" | Sort-Object Name
if ($parts.Count -eq 0) {
  Write-Host "ERROR: no $zipName.partNNN chunks found next to this script." -ForegroundColor Red
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

Write-Host "Extracting to $extractDir ..." -ForegroundColor Cyan
if (Test-Path $extractDir) { Remove-Item $extractDir -Recurse -Force }
Expand-Archive -Path $zipPath -DestinationPath $extractDir

Write-Host "Cleaning up build artifacts..." -ForegroundColor Cyan
Remove-Item $zipPath -Force
Remove-Item $parts.FullName -Force
$srcDir = Join-Path $root "src"
if (Test-Path $srcDir) { Remove-Item $srcDir -Recurse -Force }

Write-Host ""
Write-Host "Done. Deployment bundle ready at: $extractDir" -ForegroundColor Green
Write-Host "Next: cd there and run deploy.ps1 (see README-WINDOWS.md)."

# Best-effort self-delete -- PowerShell doesn't hold an exclusive lock on a
# running .ps1, so this succeeds on Windows/PowerShell 7+ in practice, but
# isn't guaranteed on every OS/filesystem, hence -ErrorAction SilentlyContinue.
Remove-Item -LiteralPath $PSCommandPath -Force -ErrorAction SilentlyContinue
