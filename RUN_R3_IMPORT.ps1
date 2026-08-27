$ErrorActionPreference = 'Stop'
$ProjectRoot = $PSScriptRoot
$GodotExe = & (Join-Path $ProjectRoot 'tools\Find-Godot471.ps1')
$LogPath = Join-Path $ProjectRoot 'qa\R3_IMPORT.log'
$PreviousAppData = $env:APPDATA
$PreviousLocalAppData = $env:LOCALAPPDATA
$SystemTempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
$ImportUserHome = [IO.Path]::GetFullPath((Join-Path $SystemTempRoot ("relic-reserve-r3-import-" + [Guid]::NewGuid().ToString('N'))))
$ResolvedImportHome = $ImportUserHome.TrimEnd('\') + '\'
if (-not $ResolvedImportHome.StartsWith($SystemTempRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to create an isolated Godot import home outside the system temp directory: $ResolvedImportHome"
}
[void](New-Item -ItemType Directory -Path $ImportUserHome -Force)
$env:APPDATA = $ImportUserHome
$env:LOCALAPPDATA = $ImportUserHome

try {
    & $GodotExe --headless --import --log-file $LogPath --path $ProjectRoot
    if ($LASTEXITCODE -ne 0) {
        throw "Godot import failed with exit code $LASTEXITCODE. See $LogPath"
    }
}
finally {
    if ($null -eq $PreviousAppData) {
        Remove-Item Env:APPDATA -ErrorAction SilentlyContinue
    }
    else {
        $env:APPDATA = $PreviousAppData
    }
    if ($null -eq $PreviousLocalAppData) {
        Remove-Item Env:LOCALAPPDATA -ErrorAction SilentlyContinue
    }
    else {
        $env:LOCALAPPDATA = $PreviousLocalAppData
    }
    $CleanupPath = [IO.Path]::GetFullPath($ImportUserHome).TrimEnd('\') + '\'
    if (-not $CleanupPath.StartsWith($SystemTempRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove an import home outside the system temp directory: $CleanupPath"
    }
    if (Test-Path -LiteralPath $ImportUserHome -PathType Container) {
        Remove-Item -LiteralPath $ImportUserHome -Recurse -Force
    }
}
Write-Output "R3 import PASS — $GodotExe"
