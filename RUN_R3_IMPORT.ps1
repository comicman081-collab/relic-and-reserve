$ErrorActionPreference = 'Stop'
$ProjectRoot = $PSScriptRoot
$GodotExe = & (Join-Path $ProjectRoot 'tools\Find-Godot471.ps1')
$LogPath = Join-Path $ProjectRoot 'qa\R3_IMPORT.log'

& $GodotExe --editor --headless --log-file $LogPath --path $ProjectRoot --quit
if ($LASTEXITCODE -ne 0) {
    throw "Godot import failed with exit code $LASTEXITCODE. See $LogPath"
}
Write-Output "R3 import PASS — $GodotExe"
