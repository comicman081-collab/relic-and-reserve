param(
    [string]$OutputPath = (Join-Path $PSScriptRoot '..\audio\ui_click.wav')
)

# Deterministic, clean UI click: short two-tone chime with a smooth attack/release.
# No noise source or external asset is used.
$sampleRate = 22050
$durationSeconds = 0.085
$sampleCount = [int]([Math]::Round($sampleRate * $durationSeconds))
$pcm = New-Object byte[] ($sampleCount * 2)

for ($i = 0; $i -lt $sampleCount; $i++) {
    $t = $i / [double]$sampleRate
    $attack = 1.0 - [Math]::Exp(-$t / 0.0007)
    $release = [Math]::Exp(-$t / 0.022)
    $envelope = $attack * $release

    # Lower, rounded two-tone body. Keep all energy below the harsh high-frequency band.
    $body = (0.74 * [Math]::Sin(2.0 * [Math]::PI * 720.0 * $t))
    $body += (0.16 * [Math]::Sin(2.0 * [Math]::PI * 1080.0 * $t))
    $body += (0.045 * [Math]::Sin(2.0 * [Math]::PI * 1440.0 * $t))
    $softThump = 0.07 * [Math]::Sin(2.0 * [Math]::PI * 180.0 * $t) * [Math]::Exp(-$t / 0.010)
    $value = [Math]::Max(-1.0, [Math]::Min(1.0, ($body + $softThump) * $envelope))
    $sample = [int][Math]::Round($value * 15500.0)
    [Array]::Copy([BitConverter]::GetBytes([int16]$sample), 0, $pcm, $i * 2, 2)
}

$directory = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
}

$stream = [IO.File]::Open($OutputPath, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::None)
try {
    $writer = New-Object IO.BinaryWriter($stream)
    $writer.Write([Text.Encoding]::ASCII.GetBytes('RIFF'))
    $writer.Write([int32](36 + $pcm.Length))
    $writer.Write([Text.Encoding]::ASCII.GetBytes('WAVE'))
    $writer.Write([Text.Encoding]::ASCII.GetBytes('fmt '))
    $writer.Write([int32]16)
    $writer.Write([int16]1)
    $writer.Write([int16]1)
    $writer.Write([int32]$sampleRate)
    $writer.Write([int32]($sampleRate * 2))
    $writer.Write([int16]2)
    $writer.Write([int16]16)
    $writer.Write([Text.Encoding]::ASCII.GetBytes('data'))
    $writer.Write([int32]$pcm.Length)
    $writer.Write($pcm)
    $writer.Flush()
    $writer.Dispose()
} finally {
    $stream.Dispose()
}

Write-Output ("Generated clean UI click: {0} ({1} ms, {2} Hz)" -f $OutputPath, [Math]::Round($durationSeconds * 1000), $sampleRate)
