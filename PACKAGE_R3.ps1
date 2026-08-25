param([switch]$UserAuthorized)

if (-not $UserAuthorized) {
    throw 'RELEASE HOLD: Windows/source archive creation requires a new explicit user instruction. Re-run with -UserAuthorized only after that instruction.'
}

$ErrorActionPreference = 'Stop'
$ProjectRoot = $PSScriptRoot
$BuildRoot = Join-Path $ProjectRoot 'builds\r3'
$WindowsRoot = Join-Path $BuildRoot 'windows'
$WindowsZip = Join-Path $BuildRoot 'RELIC_AND_RESERVE_R3_WINDOWS.zip'
$SourceZip = Join-Path $BuildRoot 'RELIC_AND_RESERVE_R3_SOURCE.zip'

& (Join-Path $ProjectRoot 'RUN_R3_TESTS.ps1')
& (Join-Path $ProjectRoot 'BUILD_R3_WINDOWS.ps1') -UserAuthorized

if (Test-Path -LiteralPath $WindowsZip) { Remove-Item -LiteralPath $WindowsZip -Force }
Compress-Archive -LiteralPath (Join-Path $WindowsRoot 'RelicAndReserve_R3.exe') -DestinationPath $WindowsZip -CompressionLevel Optimal

$Staging = Join-Path $BuildRoot '_source_staging\RELIC_AND_RESERVE_R3'
if (Test-Path -LiteralPath $Staging) { Remove-Item -LiteralPath $Staging -Recurse -Force }
New-Item -ItemType Directory -Force -Path $Staging | Out-Null
$ExcludedTop = @('.godot', 'builds')
Get-ChildItem -LiteralPath $ProjectRoot -Force | Where-Object { $_.Name -notin $ExcludedTop } | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $Staging -Recurse -Force
}
if (Test-Path -LiteralPath $SourceZip) { Remove-Item -LiteralPath $SourceZip -Force }
Compress-Archive -LiteralPath $Staging -DestinationPath $SourceZip -CompressionLevel Optimal
Remove-Item -LiteralPath (Split-Path -Parent $Staging) -Recurse -Force

$ChecksumPath = Join-Path $BuildRoot 'SHA256SUMS_R3.txt'
$Artifacts = @(
    (Join-Path $WindowsRoot 'RelicAndReserve_R3.exe'),
    $WindowsZip,
    $SourceZip
)
$Lines = foreach ($Artifact in $Artifacts) {
    $Hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Artifact).Hash.ToLowerInvariant()
    $Relative = $Artifact.Substring($BuildRoot.Length + 1).Replace('\','/')
    "{0}  {1}" -f $Hash, $Relative
}
$Lines | Set-Content -LiteralPath $ChecksumPath -Encoding utf8
Write-Output "R3 package PASS — $BuildRoot"
