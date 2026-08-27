$ErrorActionPreference = 'Stop'

$ProjectRoot = $PSScriptRoot
$ConsoleGodot = & (Join-Path $ProjectRoot 'tools\Find-Godot471.ps1')
$BackgroundGodot = $ConsoleGodot -replace '_console\.exe$', '.exe'
if (-not (Test-Path -LiteralPath $BackgroundGodot -PathType Leaf)) {
    $BackgroundGodot = $ConsoleGodot
}
$PreviousAppData = $env:APPDATA
$PreviousLocalAppData = $env:LOCALAPPDATA
$SystemTempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
$ViewportUserHome = [IO.Path]::GetFullPath((Join-Path $SystemTempRoot ("relic-reserve-r3-viewport-" + [Guid]::NewGuid().ToString('N'))))
$ResolvedViewportHome = $ViewportUserHome.TrimEnd('\') + '\'
if (-not $ResolvedViewportHome.StartsWith($SystemTempRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to create an isolated viewport home outside the system temp directory: $ResolvedViewportHome"
}
[void](New-Item -ItemType Directory -Path $ViewportUserHome -Force)
$env:APPDATA = $ViewportUserHome
$env:LOCALAPPDATA = $ViewportUserHome

$Arguments = @(
    '--display-driver', 'windows',
    '--rendering-driver', 'opengl3',
    '--audio-driver', 'Dummy',
    '--windowed',
    '--position', '-32000,-32000',
    '--path', '.',
    '--script', 'res://tests/capture_latest_runtime_viewport.gd',
    '--log-file', 'qa/R3_LATEST_RUNTIME_VIEWPORT_QA.hidden.log'
)

try {
    $Process = Start-Process `
        -FilePath $BackgroundGodot `
        -ArgumentList $Arguments `
        -WorkingDirectory $ProjectRoot `
        -WindowStyle Hidden `
        -Wait `
        -PassThru
    $ViewportExitCode = $Process.ExitCode
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
    $CleanupPath = [IO.Path]::GetFullPath($ViewportUserHome).TrimEnd('\') + '\'
    if (-not $CleanupPath.StartsWith($SystemTempRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove a viewport home outside the system temp directory: $CleanupPath"
    }
    if (Test-Path -LiteralPath $ViewportUserHome -PathType Container) {
        Remove-Item -LiteralPath $ViewportUserHome -Recurse -Force
    }
}

if ($ViewportExitCode -ne 0) {
    throw "R3 actual viewport QA failed. See qa\R3_LATEST_RUNTIME_VIEWPORT_QA.hidden.log and qa\R3_LATEST_RUNTIME_VIEWPORT_QA.json."
}

Write-Output 'R3 actual 1280x720 runtime viewport QA PASS (hidden/background OpenGL process).'
