$ErrorActionPreference = 'Stop'

$Candidates = [System.Collections.Generic.List[string]]::new()
if ($env:GODOT_PATH) {
    $Candidates.Add($env:GODOT_PATH)
}
$Candidates.Add('D:\AI 종합 폴더\Godot\4.7.1-standard\Godot_v4.7.1-stable_win64_console.exe')
$Candidates.Add('D:\AI 종합 폴더\Godot\4.7.1-standard\Godot_v4.7.1-stable_win64.exe')
$Candidates.Add((Join-Path $PSScriptRoot '..\.tools\Godot_v4.7.1-stable_win64_console.exe'))
$Candidates.Add((Join-Path $PSScriptRoot '..\.tools\Godot_v4.7.1-stable_win64.exe'))

foreach ($Candidate in $Candidates) {
    if (-not $Candidate -or -not (Test-Path -LiteralPath $Candidate -PathType Leaf)) {
        continue
    }
    # Do not use $LASTEXITCODE here: when this helper is invoked from another
    # PowerShell script, the pipeline can retain the caller's previous native
    # exit code even though the version probe returned valid output.
    $VersionLine = & $Candidate --version 2>$null | Select-Object -First 1
    $Version = if ($null -eq $VersionLine) { '' } else { $VersionLine.ToString().Trim() }
    if ($Version.StartsWith('4.7.1.stable')) {
        return (Resolve-Path -LiteralPath $Candidate).Path
    }
}

throw 'Godot 4.7.1 stable Standard was not found. Set GODOT_PATH to the exact Windows executable. Other versions are rejected.'
