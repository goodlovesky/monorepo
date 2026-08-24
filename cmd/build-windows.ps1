param(
  [switch]$Clean,
  [switch]$SkipTests,
  [switch]$Help
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
if ($Help) {
  Write-Host 'Usage: .\cmd\build-windows.ps1 [-Clean] [-SkipTests]'
  exit 0
}
if (-not $IsWindows -and $PSVersionTable.PSEdition -eq 'Core') {
  throw 'Windows packaging must run on Windows'
}
$arguments = @('-Architecture', 'x64', '-Installer')
if ($Clean) { $arguments += '-Clean' }
if ($SkipTests) { $arguments += '-SkipTests' }
& (Join-Path $Root 'tools\build_windows.ps1') @arguments
if ($LASTEXITCODE -ne 0) { throw "Windows packaging failed: $LASTEXITCODE" }
Write-Host "Windows packages: $(Join-Path $Root 'dist\windows')"
