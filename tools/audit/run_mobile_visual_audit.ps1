param(
    [string]$GodotExe = 'D:\AI 종합 폴더\Godot\4.7.1-standard\Godot_v4.7.1-stable_win64_console.exe',
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

# The real renderer is deliberately kept hidden. Godot --headless has no
# Windows framebuffer, so this runner supplies evidence for the mobile visual
# audit without opening the editor or a game window.
$ErrorActionPreference = 'Stop'
$stdoutPath = Join-Path $ProjectRoot 'qa\mobile_visual_audit.stdout.log'
$stderrPath = Join-Path $ProjectRoot 'qa\mobile_visual_audit.stderr.log'
Remove-Item -LiteralPath $stdoutPath, $stderrPath -Force -ErrorAction SilentlyContinue

$arguments = @(
    '--path', $ProjectRoot,
    '--display-driver', 'windows',
    '--rendering-method', 'gl_compatibility',
    '--rendering-driver', 'opengl3',
    '--audio-driver', 'Dummy',
    '--resolution', '390x700',
    '--script', 'res://tests/audit/capture_mobile_visual_audit.gd'
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
    throw "Could not start hidden Godot mobile visual audit: $GodotExe"
}
$stdoutTask = $process.StandardOutput.ReadToEndAsync()
$stderrTask = $process.StandardError.ReadToEndAsync()
$process.WaitForExit()
$stdoutTask.GetAwaiter().GetResult() | Set-Content -LiteralPath $stdoutPath -Encoding UTF8
$stderrTask.GetAwaiter().GetResult() | Set-Content -LiteralPath $stderrPath -Encoding UTF8

[pscustomobject]@{
    exitCode = $process.ExitCode
    displayDriver = 'windows'
    renderingMethod = 'gl_compatibility'
    resolution = '390x700'
    backgroundOnly = $true
    standardOutput = $stdoutPath
    standardError = $stderrPath
} | ConvertTo-Json -Depth 3
exit $process.ExitCode
