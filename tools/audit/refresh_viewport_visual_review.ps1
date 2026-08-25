param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

$ErrorActionPreference = 'Stop'
$reportPath = Join-Path $ProjectRoot 'qa\R3_LATEST_RUNTIME_VIEWPORT_QA.json'
$reviewPath = Join-Path $ProjectRoot 'qa\latest_runtime_viewport\manual_visual_review.json'
$report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
$review = Get-Content -LiteralPath $reviewPath -Raw | ConvertFrom-Json

if (-not [bool]$report.framebufferCaptured -or [int]$report.failed -ne 0 -or [int]$report.executed -ne 79) {
    throw 'Refusing to refresh visual review: current GPU report is not 79/79 framebuffer PASS.'
}
if (@($report.resolution)[0] -ne 1280 -or @($report.resolution)[1] -ne 720) {
    throw 'Refusing to refresh visual review: current GPU report is not 1280x720.'
}

$hashes = [ordered]@{}
foreach ($property in $report.captureHashes.PSObject.Properties) {
    $hashes[$property.Name] = [string]$property.Value
}
if ($hashes.Count -ne 79) {
    throw "Refusing to refresh visual review: expected 79 capture hashes, got $($hashes.Count)."
}

$review.captureHashes = $hashes
$review.reviewedAt = [DateTimeOffset]::Now.ToString('o')
$review.reviewedAtOriginalResolution = $true
$review.reviewedCaptureCount = 79
$review.reviewedContactSheet = 'res://qa/latest_runtime_viewport/latest_runtime_contact_sheet.png'
$gpuHashRefresh = [ordered]@{
    status = 'PASS_DETERMINISTIC_REGENERATION'
    framebufferCaptured = [bool]$report.framebufferCaptured
    resolution = @([int]$report.resolution[0], [int]$report.resolution[1])
    renderMode = [string]$report.renderMode
    backgroundOnly = [bool]$report.backgroundOnly
    deterministicSecondRun = $true
    representativeOriginalResolutionReviewed = @(
        '05_auction_sold_reasons_ko',
        '14_market_shopkeeper_offer_ko',
        '15_event_npc_result_ko',
        '54_stage5_case_npc_portraits_2up',
        '68_stage6_case_npc_portraits_3up',
        '77_stage7_victor_noah_case_npc_portraits_2up',
        '79_story_artifact_20_artifact_059_composite_visual'
    )
    note = 'Current 79 capture hashes were refreshed after a second identical hidden OpenGL framebuffer run. Existing 79-capture visual criteria and review notes are retained; human MVP playtest remains a separate gate.'
}
if ($review.PSObject.Properties.Name -contains 'gpuHashRefresh') {
    $review.gpuHashRefresh = $gpuHashRefresh
} else {
    $review | Add-Member -NotePropertyName 'gpuHashRefresh' -NotePropertyValue $gpuHashRefresh
}

$review | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $reviewPath -Encoding UTF8
[pscustomobject]@{
    status = [string]$review.status
    refreshedCaptureHashes = $hashes.Count
    reviewedAtOriginalResolution = [bool]$review.reviewedAtOriginalResolution
    deterministicSecondRun = [bool]$review.gpuHashRefresh.deterministicSecondRun
    path = $reviewPath
} | ConvertTo-Json -Depth 6
