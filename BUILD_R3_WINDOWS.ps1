param([switch]$UserAuthorized)

if (-not $UserAuthorized) {
    throw 'RELEASE HOLD: Windows EXE/PCK creation requires a new explicit user instruction. Re-run with -UserAuthorized only after that instruction.'
}

$ErrorActionPreference = 'Stop'
$ProjectRoot = $PSScriptRoot
$GodotExe = & (Join-Path $ProjectRoot 'tools\Find-Godot471.ps1')
$BuildRoot = Join-Path $ProjectRoot 'builds\r3\windows'
$Executable = Join-Path $BuildRoot 'RelicAndReserve_R3.exe'
$LogPath = Join-Path $ProjectRoot 'qa\R3_WINDOWS_BUILD.log'

New-Item -ItemType Directory -Force -Path $BuildRoot | Out-Null
& $GodotExe --headless --log-file $LogPath --path $ProjectRoot --export-release 'Windows Desktop' $Executable
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $Executable -PathType Leaf)) {
    throw "R3 Windows export failed. See $LogPath"
}

Get-FileHash -Algorithm SHA256 -LiteralPath $Executable | ForEach-Object {
    "{0}  {1}" -f $_.Hash.ToLowerInvariant(), 'windows/RelicAndReserve_R3.exe'
} | Set-Content -LiteralPath (Join-Path $ProjectRoot 'builds\r3\SHA256SUMS_R3.txt') -Encoding utf8

Write-Output "R3 Windows build PASS — $Executable"
$paramBlock = $null
