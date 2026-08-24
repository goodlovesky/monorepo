param(
  [string]$Version = 'v1.19.30',
  [string]$MihomoSha256 = '289fde5e29d37a5b3326480590d8b3551c5bf7f8737290355c19bce74d57a563',
  [string]$WintunVersion = '0.14.1',
  [string]$WintunSha256 = '07c256185d6ee3652e09fa55c0b673e2624b565e02c4b9091c79ca7d2f24ef51',
  [switch]$Force
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Root = Split-Path -Parent $PSScriptRoot
$Dest = Join-Path $Root 'app\windows\runner\resources\mihomo.exe'
$WintunDest = Join-Path $Root 'app\windows\runner\resources\wintun.dll'
$MetadataDest = Join-Path $Root 'app\windows\runner\resources\WINDOWS-RUNTIME.txt'

if ($Version -notmatch '^v\d+\.\d+\.\d+$') { throw "Invalid mihomo version: $Version" }
if ($MihomoSha256 -notmatch '^[0-9a-fA-F]{64}$') { throw 'Mihomo SHA256 must contain 64 hexadecimal characters' }
if ($WintunSha256 -notmatch '^[0-9a-fA-F]{64}$') { throw 'Wintun SHA256 must contain 64 hexadecimal characters' }

function Get-VerifiedDownload([string]$Uri, [string]$Destination, [string]$ExpectedHash) {
  Invoke-WebRequest -Uri $Uri -OutFile $Destination -UseBasicParsing
  $actual = (Get-FileHash $Destination -Algorithm SHA256).Hash.ToLowerInvariant()
  if ($actual -ne $ExpectedHash.ToLowerInvariant()) {
    Remove-Item $Destination -Force -ErrorAction SilentlyContinue
    throw "SHA256 mismatch for $Uri. expected=$ExpectedHash actual=$actual"
  }
}

$Name = "mihomo-windows-amd64-compatible-$Version.zip"
$Url = "https://github.com/MetaCubeX/mihomo/releases/download/$Version/$Name"
$Cache = Join-Path $Root '.dart_tool\windows-runtime-cache'
$MihomoZip = Join-Path $Cache $Name
$WintunZip = Join-Path $Cache "wintun-$WintunVersion.zip"
$ExtractRoot = Join-Path $Cache 'extract'

New-Item -ItemType Directory -Force -Path $Cache, (Split-Path $Dest) | Out-Null

$needMihomo = $Force -or -not (Test-Path $MihomoZip) -or
  ((Get-FileHash $MihomoZip -Algorithm SHA256).Hash.ToLowerInvariant() -ne $MihomoSha256.ToLowerInvariant())
if ($needMihomo) { Get-VerifiedDownload $Url $MihomoZip $MihomoSha256 }

$WintunUrl = "https://www.wintun.net/builds/wintun-$WintunVersion.zip"
$needWintun = $Force -or -not (Test-Path $WintunZip) -or
  ((Get-FileHash $WintunZip -Algorithm SHA256).Hash.ToLowerInvariant() -ne $WintunSha256.ToLowerInvariant())
if ($needWintun) { Get-VerifiedDownload $WintunUrl $WintunZip $WintunSha256 }

Remove-Item $ExtractRoot -Recurse -Force -ErrorAction SilentlyContinue
$MihomoDir = Join-Path $ExtractRoot 'mihomo'
$WintunDir = Join-Path $ExtractRoot 'wintun'
Expand-Archive $MihomoZip $MihomoDir -Force
Expand-Archive $WintunZip $WintunDir -Force

$Binary = Get-ChildItem $MihomoDir -Recurse -File -Filter 'mihomo*.exe' | Select-Object -First 1
if (-not $Binary) { throw 'mihomo.exe missing from verified archive' }
$Wintun = Get-ChildItem $WintunDir -Recurse -File -Filter 'wintun.dll' |
  Where-Object { $_.FullName -match '[\\/]amd64[\\/]' } | Select-Object -First 1
if (-not $Wintun) { throw 'amd64 wintun.dll missing from verified archive' }
$WintunLicense = Get-ChildItem $WintunDir -Recurse -File |
  Where-Object { $_.Name -match '^(COPYING|LICENSE)(\.txt)?$' } | Select-Object -First 1

Copy-Item $Binary.FullName $Dest -Force
Copy-Item $Wintun.FullName $WintunDest -Force
if ($WintunLicense) {
  Copy-Item $WintunLicense.FullName (Join-Path (Split-Path $Dest) 'WINTUN-LICENSE.txt') -Force
}
$versionOutput = (& $Dest -v 2>&1 | Select-Object -First 1).ToString()
if ($LASTEXITCODE -ne 0 -or $versionOutput -notmatch [regex]::Escape($Version.TrimStart('v'))) {
  throw "Unexpected mihomo binary version: $versionOutput"
}

@(
  "mihomo.version=$Version",
  "mihomo.archive.sha256=$($MihomoSha256.ToLowerInvariant())",
  'mihomo.source=https://github.com/MetaCubeX/mihomo',
  "wintun.version=$WintunVersion",
  "wintun.archive.sha256=$($WintunSha256.ToLowerInvariant())",
  'wintun.source=https://www.wintun.net/'
) | Set-Content -Encoding ascii $MetadataDest

Remove-Item $ExtractRoot -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "Runtime ready: $versionOutput; Wintun $WintunVersion"
