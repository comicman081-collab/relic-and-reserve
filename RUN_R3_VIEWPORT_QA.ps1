$ErrorActionPreference = 'Stop'

$ProjectRoot = $PSScriptRoot
$ConsoleGodot = & (Join-Path $ProjectRoot 'tools\Find-Godot471.ps1')
$BackgroundGodot = $ConsoleGodot -replace '_console\.exe$', '.exe'
if (-not (Test-Path -LiteralPath $BackgroundGodot -PathType Leaf)) {
    $BackgroundGodot = $ConsoleGodot
}

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

$Process = Start-Process `
    -FilePath $BackgroundGodot `
    -ArgumentList $Arguments `
    -WorkingDirectory $ProjectRoot `
    -WindowStyle Hidden `
    -Wait `
    -PassThru

if ($Process.ExitCode -ne 0) {
    throw "R3 actual viewport QA failed. See qa\R3_LATEST_RUNTIME_VIEWPORT_QA.hidden.log and qa\R3_LATEST_RUNTIME_VIEWPORT_QA.json."
}

Write-Output 'R3 actual 1280x720 runtime viewport QA PASS (hidden/background OpenGL process).'
