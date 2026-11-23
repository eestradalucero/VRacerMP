<#
.SYNOPSIS
  Builds the VRacerMP release into export/Resources and optionally installs it on a BeamMP server.

.DESCRIPTION
  - Server: copies Resources/Server/VRacerMP, plus /shared into vracerMP/shared, and zips it as
    export/Resources/Server/VRacerMP-server.zip (VRacerMP/ inside) for hosts that take plugin uploads.
  - Client: zips Resources/Client (lua, scripts, ui, LICENSE, and gameplay if present), plus /shared into
    lua/ge/extensions/vracerMP/shared, as export/Resources/Client/VRacerMP-client.zip.
  The zips are named -server and -client (B-14) so the two are not mixed up when uploading.
  The zip is written with forward-slash paths (Compress-Archive on PowerShell 5.1 writes
  backslashes, which BeamNG cannot read).

.PARAMETER ServerPath
  Optional BeamMP server folder (the one containing ServerConfig.toml). When given, the
  build is copied into its Resources folder. Only VRacerMP files are replaced. That copy is a
  local test server: its testing commands (`fake`) are turned on. The release zip keeps them off.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File tools/build.ps1
  powershell -ExecutionPolicy Bypass -File tools/build.ps1 -ServerPath "C:\Users\me\Desktop\BeamMP Server"
#>
param(
  [string]$ServerPath
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$repoRoot = Split-Path -Parent $PSScriptRoot
$sharedFolder = Join-Path $repoRoot "shared"
$exportResources = Join-Path $repoRoot "export\Resources"
$serverSource = Join-Path $repoRoot "Resources\Server\VRacerMP"
$clientSource = Join-Path $repoRoot "Resources\Client"
$clientItems = @("lua", "scripts", "ui", "gameplay", "LICENSE")
$serverZipName = "VRacerMP-server.zip"
$clientZipName = "VRacerMP-client.zip"

function Reset-Folder([string]$path) {
  if (Test-Path $path) { Remove-Item -Recurse -Force $path }
  New-Item -ItemType Directory -Force $path | Out-Null
}

# Build output only: old zips (e.g. VRacerMP.zip before B-14) must not sit next to the new one.
function Remove-OldZips([string]$folder) {
  if (Test-Path $folder) { Get-ChildItem $folder -Filter "*.zip" -File | Remove-Item -Force }
}

function Copy-SharedCode([string]$destination) {
  New-Item -ItemType Directory -Force $destination | Out-Null
  Copy-Item (Join-Path $sharedFolder "*.lua") $destination
}

function Build-Server {
  $destination = Join-Path $exportResources "Server\VRacerMP"
  Reset-Folder $destination
  Copy-Item (Join-Path $serverSource "*") $destination -Recurse
  Copy-SharedCode (Join-Path $destination "vracerMP\shared")
  Remove-OldZips (Join-Path $exportResources "Server")
  $zipPath = Join-Path $exportResources "Server\$serverZipName"
  New-ZipFromFolder $destination $zipPath "VRacerMP/"
  Write-Host "Server plugin -> $destination"
  Write-Host "Server zip    -> $zipPath"
}

# $entryPrefix puts the files inside a folder in the zip, e.g. "VRacerMP/".
function New-ZipFromFolder([string]$sourceFolder, [string]$zipPath, [string]$entryPrefix = "") {
  if (Test-Path $zipPath) { Remove-Item -Force $zipPath }
  $zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
  try {
    $sourceRoot = (Resolve-Path $sourceFolder).Path.TrimEnd('\') + '\'
    Get-ChildItem $sourceFolder -Recurse -File | ForEach-Object {
      $entryName = $entryPrefix + $_.FullName.Substring($sourceRoot.Length).Replace('\', '/')
      [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $entryName) | Out-Null
    }
  } finally {
    $zip.Dispose()
  }
}

function Build-Client {
  $staging = Join-Path $repoRoot "export\clientStaging"
  Reset-Folder $staging
  foreach ($item in $clientItems) {
    $itemPath = Join-Path $clientSource $item
    if (Test-Path $itemPath) { Copy-Item $itemPath $staging -Recurse }
  }
  Copy-SharedCode (Join-Path $staging "lua\ge\extensions\vracerMP\shared")

  $clientDestination = Join-Path $exportResources "Client"
  New-Item -ItemType Directory -Force $clientDestination | Out-Null
  Remove-OldZips $clientDestination
  $zipPath = Join-Path $clientDestination $clientZipName
  New-ZipFromFolder $staging $zipPath
  Remove-Item -Recurse -Force $staging
  Write-Host "Client mod    -> $zipPath"
}

# Only the local install gets the testing commands (serverOptions.lua).
function Enable-TestingCommands([string]$optionsPath) {
  $options = [System.IO.File]::ReadAllText($optionsPath)
  $enabled = $options.Replace("testingCommands = false", "testingCommands = true")
  if ($enabled -eq $options) { throw "testingCommands not found in $optionsPath" }
  [System.IO.File]::WriteAllText($optionsPath, $enabled)
  Write-Host "Testing commands on (local test server)"
}

function Install-OnServer([string]$serverFolder) {
  $serverResources = Join-Path $serverFolder "Resources"
  if (-not (Test-Path $serverResources)) { throw "No Resources folder in $serverFolder" }

  $installedPlugin = Join-Path $serverResources "Server\VRacerMP"
  Reset-Folder $installedPlugin
  Copy-Item (Join-Path $exportResources "Server\VRacerMP\*") $installedPlugin -Recurse
  Enable-TestingCommands (Join-Path $installedPlugin "vracerMP\serverOptions.lua")

  Copy-Item (Join-Path $exportResources "Client\$clientZipName") (Join-Path $serverResources "Client") -Force
  Write-Host "Installed on  -> $serverResources"
}

Build-Server
Build-Client
if ($ServerPath) { Install-OnServer $ServerPath }
