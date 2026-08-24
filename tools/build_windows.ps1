param(
  [ValidateSet('x64')][string]$Architecture = 'x64',
  [switch]$SkipTests,
  [switch]$Installer,
  [switch]$Clean,
  [string]$SignTool = ''
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$Root = Split-Path -Parent $PSScriptRoot
$App = Join-Path $Root 'app'
$Dist = Join-Path $Root 'dist\windows'
$Release = Join-Path $App 'build\windows\x64\runner\Release'
$Pubspec = Get-Content (Join-Path $App 'pubspec.yaml') -Raw
$VersionMatch = [regex]::Match($Pubspec, '(?m)^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)\s*$')
if (-not $VersionMatch.Success) { throw 'Unable to read semantic version from app/pubspec.yaml' }
$AppVersion = $VersionMatch.Groups[1].Value
$BuildNumber = $VersionMatch.Groups[2].Value
$PortableName = "ClashRS-$AppVersion-windows-$Architecture-portable.zip"
$InstallerName = "ClashRS-Setup-$AppVersion-$Architecture.exe"

function Assert-File([string]$Path) {
  if (-not (Test-Path $Path -PathType Leaf)) { throw "Required packaged file is missing: $Path" }
  if ((Get-Item $Path).Length -le 0) { throw "Required packaged file is empty: $Path" }
}

function Invoke-Native([string]$Command, [string[]]$Arguments) {
  & $Command @Arguments
  if ($LASTEXITCODE -ne 0) { throw "$Command failed with exit code $LASTEXITCODE" }
}

if ($Clean) {
  Remove-Item $Dist -Recurse -Force -ErrorAction SilentlyContinue
  Remove-Item (Join-Path $App 'build\windows') -Recurse -Force -ErrorAction SilentlyContinue
}
New-Item -ItemType Directory -Force -Path $Dist | Out-Null
Push-Location $Root
try {
  if (-not $SkipTests) {
    Push-Location $App
    try {
      Invoke-Native 'flutter' @('pub', 'get')
      Invoke-Native 'flutter' @('analyze')
      Invoke-Native 'flutter' @('test')
    } finally { Pop-Location }
  }
  $Mihomo = Join-Path $Root 'app\windows\runner\resources\mihomo.exe'
  $Wintun = Join-Path $Root 'app\windows\runner\resources\wintun.dll'
  $RuntimeMetadata = Join-Path $Root 'app\windows\runner\resources\WINDOWS-RUNTIME.txt'
  # Always execute the verified runtime resolver. Mere file existence is not a
  # supply-chain check and could silently package a stale local binary.
  & (Join-Path $Root 'tools\download_mihomo_windows.ps1')
  Push-Location $App
  try {
    Invoke-Native 'flutter' @(
      'build', 'windows', '--release',
      "--build-name=$AppVersion", "--build-number=$BuildNumber"
    )
  } finally { Pop-Location }
  Copy-Item $Mihomo $Release -Force
  Copy-Item $Wintun $Release -Force
  if (Test-Path $RuntimeMetadata) { Copy-Item $RuntimeMetadata $Release -Force }
  Get-ChildItem (Split-Path $Mihomo) -File -Filter '*-LICENSE.txt' -ErrorAction SilentlyContinue |
    Copy-Item -Destination $Release -Force

  $Required = @(
    (Join-Path $Release 'clash_rs.exe'),
    (Join-Path $Release 'flutter_windows.dll'),
    (Join-Path $Release 'data\icudtl.dat'),
    (Join-Path $Release 'data\flutter_assets\AssetManifest.bin'),
    (Join-Path $Release 'mihomo.exe'),
    (Join-Path $Release 'wintun.dll')
  )
  $Required | ForEach-Object { Assert-File $_ }

  if ($SignTool) {
    foreach ($artifact in @((Join-Path $Release 'clash_rs.exe'), (Join-Path $Release 'mihomo.exe'))) {
      Invoke-Expression ($SignTool.Replace('{file}', ('"' + $artifact + '"')))
      if ($LASTEXITCODE -ne 0) { throw "Signing failed: $artifact" }
    }
  }

  $Portable = Join-Path $Dist $PortableName
  if (Test-Path $Portable) { Remove-Item $Portable -Force }
  Compress-Archive -Path (Join-Path $Release '*') -DestinationPath $Portable -CompressionLevel Optimal
  Assert-File $Portable

  if ($Installer) {
    $Iscc = Get-Command ISCC.exe -ErrorAction SilentlyContinue
    if (-not $Iscc) { throw 'ISCC.exe is required when -Installer is used' }
    Invoke-Native $Iscc.Source @(
      "/DSourceDir=$Release",
      "/DOutputDir=$Dist",
      "/DMyAppVersion=$AppVersion",
      "/DMyOutputBase=ClashRS-Setup-$AppVersion-$Architecture",
      (Join-Path $Root 'tools\windows-installer.iss')
    )
    Assert-File (Join-Path $Dist $InstallerName)
    if ($SignTool) {
      $artifact = Join-Path $Dist $InstallerName
      Invoke-Expression ($SignTool.Replace('{file}', ('"' + $artifact + '"')))
      if ($LASTEXITCODE -ne 0) { throw "Signing failed: $artifact" }
    }
  }

  $FlutterVersionOutput = @(& flutter --version 2>&1)
  if ($LASTEXITCODE -ne 0) { throw "flutter --version failed with exit code $LASTEXITCODE" }
  $FlutterVersion = [string]$FlutterVersionOutput[0]
  $EnvironmentFile = Join-Path $Dist 'BUILD-ENVIRONMENT.txt'
  @(
    "built_at=$([DateTime]::UtcNow.ToString('o'))",
    "app_version=$AppVersion",
    "build_number=$BuildNumber",
    "architecture=$Architecture",
    "flutter=$FlutterVersion",
    "powershell=$($PSVersionTable.PSVersion)",
    "windows=$([Environment]::OSVersion.VersionString)"
  ) | Set-Content -Encoding utf8 $EnvironmentFile

  $releaseFiles = Get-ChildItem $Release -Recurse -File | Sort-Object FullName | ForEach-Object {
    [ordered]@{
      path = $_.FullName.Substring($Release.Length + 1).Replace('\', '/')
      size = $_.Length
      sha256 = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
  }
  $packages = Get-ChildItem $Dist -File | Where-Object { $_.Name -notin @('SHA256.txt', 'BUILD-MANIFEST.json') } |
    Sort-Object Name | ForEach-Object {
      [ordered]@{
        name = $_.Name
        size = $_.Length
        sha256 = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
      }
    }
  [ordered]@{
    schema = 1
    product = 'Clash RS'
    version = $AppVersion
    build = [int]$BuildNumber
    architecture = $Architecture
    signed = [bool]$SignTool
    packages = @($packages)
    release_files = @($releaseFiles)
  } | ConvertTo-Json -Depth 5 | Set-Content -Encoding utf8 (Join-Path $Dist 'BUILD-MANIFEST.json')

  Get-ChildItem $Dist -File | Where-Object Name -ne 'SHA256.txt' | Sort-Object Name |
    Get-FileHash -Algorithm SHA256 |
    ForEach-Object { "$($_.Hash.ToLowerInvariant())  $([IO.Path]::GetFileName($_.Path))" } |
    Set-Content -Encoding ascii (Join-Path $Dist 'SHA256.txt')

  Write-Host "Portable: $Portable"
  if ($Installer) { Write-Host "Installer: $(Join-Path $Dist $InstallerName)" }
} finally { Pop-Location }

# Do not leak a stale native-process exit code to callers after every artifact
# has been created successfully.
$global:LASTEXITCODE = 0
