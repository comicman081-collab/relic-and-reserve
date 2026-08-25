param(
    [string]$GodotExe = 'D:\AI 종합 폴더\Godot\4.7.1-standard\Godot_v4.7.1-stable_win64_console.exe',
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$stdoutPath = Join-Path $ProjectRoot 'qa\gpu_viewport_run.stdout.log'
$stderrPath = Join-Path $ProjectRoot 'qa\gpu_viewport_run.stderr.log'
Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue

$arguments = @(
    '--path', $ProjectRoot,
    '--display-driver', 'windows',
    '--rendering-method', 'gl_compatibility',
    '--rendering-driver', 'opengl3',
    '--audio-driver', 'Dummy',
    '--resolution', '1280x720',
    '--script', 'res://tests/capture_latest_runtime_viewport.gd'
)

$startInfo = [System.Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $GodotExe
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$startInfo.WindowStyle = [System.Diagnostics.ProcessWindowStyle]::Hidden
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
foreach ($argument in $arguments) {
    [void]$startInfo.ArgumentList.Add([string]$argument)
}

$process = [System.Diagnostics.Process]::new()
$process.StartInfo = $startInfo
if (-not $process.Start()) {
    throw "Could not start hidden Godot GPU capture: $GodotExe"
}
$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()
$process.WaitForExit()
$stdoutTask.GetAwaiter().GetResult() | Set-Content -LiteralPath $stdoutPath -Encoding UTF8
$stderrTask.GetAwaiter().GetResult() | Set-Content -LiteralPath $stderrPath -Encoding UTF8

[pscustomobject]@{
    exitCode = $process.ExitCode
    godotExecutable = $GodotExe
    displayDriver = 'windows'
    renderingMethod = 'gl_compatibility'
    renderingDriver = 'opengl3'
    resolution = '1280x720'
    backgroundOnly = $true
    standardOutput = $stdoutPath
    standardError = $stderrPath
} | ConvertTo-Json -Depth 4
exit $process.ExitCode
