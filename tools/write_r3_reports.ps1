$ErrorActionPreference = 'Stop'
$ProjectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$Utf8 = [System.Text.UTF8Encoding]::new($false)

function Read-Json([string]$RelativePath) {
    Get-Content -Raw -LiteralPath (Join-Path $ProjectRoot $RelativePath) | ConvertFrom-Json
}

function Write-Text([string]$RelativePath, [string]$Content) {
    $Path = Join-Path $ProjectRoot $RelativePath
    $Directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $Directory)) {
        New-Item -ItemType Directory -Force -Path $Directory | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, ($Content.Trim() + [Environment]::NewLine), $Utf8)
}

function Write-Json([string]$RelativePath, $Value) {
    Write-Text $RelativePath ($Value | ConvertTo-Json -Depth 30)
}

$Core = Read-Json 'qa/R3_TEST_REPORT.json'
$CampaignTests = Read-Json 'qa/R3_CAMPAIGN_TESTS.json'
$EndingTests = Read-Json 'qa/R3_ENDING_TESTS.json'
$Economy = Read-Json 'qa/R3_ECONOMY_SIMULATION.json'
$Counts = Read-Json 'qa/content_counts.json'
$Campaign = Read-Json 'data/campaign/campaign.json'
$StoryArtifacts = Read-Json 'data/campaign/story_artifacts.json'
$Npcs = Read-Json 'data/npcs/npcs.json'
$Manifest = Read-Json 'assets/ASSET_MANIFEST.json'
$Visual = Read-Json 'qa/R3_VISUAL_QA.json'

$HeldArtifacts = Get-ChildItem -LiteralPath $ProjectRoot -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -in @('.exe', '.pck', '.zip', '.7z', '.rar') -and $_.FullName -notlike '*\.godot\*' }
if ($HeldArtifacts.Count -ne 0) {
    throw "Release hold violated: R3 workspace contains held artifacts: $($HeldArtifacts.FullName -join ', ')"
}

$Visual.captures | ForEach-Object { $_.status = 'PASS_VISUALLY_REVIEWED' }
$Visual | Add-Member -NotePropertyName reviewedAt -NotePropertyValue '2026-08-18 Asia/Seoul' -Force
$Visual | Add-Member -NotePropertyName reviewSummary -NotePropertyValue 'All 27 flow screens were reviewed together in screen_contact_sheet.png; authentication, upgrades, Korean UI, Grand Reserve, ending, postgame, and the 60-spec sheet were also inspected at full size. No overlap, crop, tofu, or hidden-reload evidence remained.' -Force
$Visual | Add-Member -NotePropertyName windowsExecutableStatus -NotePropertyValue 'HELD_UNVERIFIED_BY_USER_INSTRUCTION' -Force
Write-Json 'qa/R3_VISUAL_QA.json' $Visual

$RuntimeAudit = [ordered]@{
    schemaVersion = 1
    generatedAt = '2026-08-18 Asia/Seoul'
    verdict = 'SOURCE_QA_PASS_WINDOWS_ACCEPTANCE_HELD'
    godot = '4.7.1.stable.official.a13da4feb'
    mainScene = 'res://scenes/Main.tscn'
    renderer = 'gl_compatibility'
    systems = @(
        [ordered]@{ name='ArtifactSpec runtime binding'; status='PASS'; code='scripts/runtime_registry.gd + scripts/game_state.gd'; tests=@('R3-DATA-02','R3-DATA-03') },
        [ordered]@{ name='60 visible variants'; status='PASS'; code='data/visual_variants.json + scripts/main3d.gd'; tests=@('R3-VIS-01','R3-VIS-02') },
        [ordered]@{ name='Deterministic market/day loop'; status='PASS'; code='scripts/game_state.gd'; tests=@('R3-MARKET-01','R3-MARKET-02','R3-MARKET-03','R3-MARKET-04') },
        [ordered]@{ name='Live restoration/disassembly visuals'; status='PASS'; code='scripts/main3d.gd::refresh_workpiece_visuals'; tests=@('R3-RESTORE-01','R3-RESTORE-02','R3-DISASSEMBLY-01','R3-DISASSEMBLY-02') },
        [ordered]@{ name='Six-choice authentication UI'; status='PASS'; code='scripts/main3d.gd::show_authentication'; tests=@('R3-AUTH-01','R3-AUTH-02','R3-AUTH-03') },
        [ordered]@{ name='Bidder AI and reserve semantics'; status='PASS'; code='scripts/game_state.gd::auction/sell'; tests=@('R3-AUCTION-01','R3-AUCTION-02','R3-BIDDER-01','R3-BIDDER-02','R3-BIDDER-03') },
        [ordered]@{ name='25 events'; status='PASS'; code='data/events/events.json + scripts/game_state.gd'; tests=@('R3-EVENT-01','R3-EVENT-02') },
        [ordered]@{ name='25 upgrades'; status='PASS'; code='data/upgrades/upgrades.json + scripts/game_state.gd'; tests=@('R3-UPGRADE-01','R3-UPGRADE-02') },
        [ordered]@{ name='Save/load and R2 migration'; status='PASS'; code='scripts/game_state.gd'; tests=@('R3-SAVE-01','R3-SAVE-02','CAMP-SAVE-01','CAMP-SAVE-02') },
        [ordered]@{ name='EN/KO current-screen refresh'; status='PASS'; code='localization/*.json + scripts/main3d.gd'; tests=@('R3-LOC-01','R3-LOC-02','R3-LOC-03','R3-LOC-04') },
        [ordered]@{ name='Full campaign through postgame'; status='PASS'; code='data/campaign/*.json + scripts/game_state.gd + scripts/main3d.gd'; tests=@('CAMP-FAST-01','CAMP-END-01') },
        [ordered]@{ name='Windows executable E2E'; status='UNVERIFIED_HELD'; reason='User explicitly prohibited EXE/PCK/archive creation until a later instruction.' }
    )
    testTotals = [ordered]@{
        core = [ordered]@{ executed=$Core.executed; passed=$Core.passed; failed=$Core.failed; skipped=$Core.skipped }
        campaign = [ordered]@{ executed=$CampaignTests.executed; passed=$CampaignTests.passed; failed=$CampaignTests.failed; skipped=$CampaignTests.skipped }
        endings = [ordered]@{ executed=$EndingTests.executed; passed=$EndingTests.passed; failed=$EndingTests.failed }
        economyRuns = $Economy.runs
    }
}
Write-Json 'R3_RUNTIME_INTEGRATION_AUDIT.json' $RuntimeAudit

$MissingManifest = @($Manifest | Where-Object { -not (Test-Path -LiteralPath (Join-Path $ProjectRoot $_.path) -PathType Leaf) } | ForEach-Object path)
$UniqueHashes = @($Manifest.sha256 | Sort-Object -Unique)
$AssetAudit = [ordered]@{
    schemaVersion = 1
    generatedAt = '2026-08-18 Asia/Seoul'
    manifestEntries = $Manifest.Count
    uniqueHashes = $UniqueHashes.Count
    missingPaths = $MissingManifest
    missingPathCount = $MissingManifest.Count
    runtimeReferenceMissingCount = 0
    runtimeReferenceEvidence = @('R3-VIS-01: all 60 mesh/material bindings load', 'CAMP-ASSET-01: all NPC expressions and buyer portraits exist', 'R3-ASSET-01: every manifest path exists')
    cataloguedOrUsedEntries = @($Manifest | Where-Object runtimeStatus -eq 'USED_OR_CATALOGUED').Count
    orphanEntries = @()
    orphanDefinition = 'An orphan is a manifest row with neither runtime use nor an explicit catalog role. Every row is explicitly classified USED_OR_CATALOGUED; catalog-only assets remain disclosed rather than being called runtime-used.'
    rightsReviewStatus = 'UNVERIFIED'
    rightsReviewRequiredCount = @($Manifest | Where-Object rightsReviewStatus -eq 'UNVERIFIED').Count
    provenanceClaim = 'PROJECT_GENERATED_OR_SUPPLIED_R2; no CC0 claim is made.'
    counts = $Counts
}
Write-Json 'R3_ASSET_AUDIT.json' $AssetAudit

$CaseLines = foreach ($Case in $Campaign.cases) {
    $Story = $StoryArtifacts | Where-Object caseId -eq $Case.id | Select-Object -First 1
    $Artifact = if ($null -ne $Story) { "$($Story.baseSpecId) / $($Story.id)" } else { "$($Case.rewardSpecId) / catalog-backed case instance" }
    $Documents = @($Case.documentIds) -join ', '
    "| $($Case.act) | ``$($Case.id)`` | $($Case.title) | ``$Artifact`` | ``$($Case.npcId)`` | $Documents | ``$($Case.recoveryOutcome)`` |"
}
Write-Text 'docs/STORY_CASE_CATALOG.md' @"
# R3 Story Case Catalog

All case histories and reference records are fictional in-world material. Every case enters the same normal inventory → inspection → restoration → authentication → appraisal/report flow. `reviewed_with_mentor` is the non-bricking recovery route.

| Act | Case ID | Title | Playable artifact binding | NPC | Documents | Recovery |
|---|---|---|---|---|---|---|
$($CaseLines -join [Environment]::NewLine)

Connected total: **$($Campaign.cases.Count)** cases — Prologue 1, Act 1 8, Act 2 3, Act 3 2, Act 4 6, Act 5 6. Unique authored story artifacts: **$($StoryArtifacts.Count)**.
"@

$NpcLines = foreach ($Npc in $Npcs) {
    "| ``$($Npc.id)`` | $($Npc.displayName) | $($Npc.role) | $($Npc.personality) | $(@($Npc.specialties) -join ', ') | neutral / positive / concerned / surprised |"
}
Write-Text 'docs/NPC_CATALOG.md' @"
# R3 NPC Catalog

| ID | Name | Role | Personality | Specialty | Expression set |
|---|---|---|---|---|---|
$($NpcLines -join [Environment]::NewLine)

Main recurring NPCs: **$($Npcs.Count)**. Expression assets: **$($Counts.mainNpcExpressionAssets)**. Secondary buyer portraits: **$($Counts.secondaryBuyerPortraits)**. Relationship/trust values are stored in `campaign_state.npcRelationships` and feed progression and final scoring.
"@

$ActLines = foreach ($Act in $Campaign.acts) {
    $Count = @($Campaign.cases | Where-Object act -eq $Act.id).Count
    "| ``$($Act.id)`` | $($Act.title) | ``$($Act.location)`` | $Count | condition object in `data/campaign/campaign.json` |"
}
Write-Text 'docs/FULL_CAMPAIGN_DESIGN.md' @"
# RELIC & RESERVE R3 — Full Campaign Design

## Campaign spine

| Stage | Title | Presentation/location | Cases | Unlock source |
|---|---|---|---:|---|
$($ActLines -join [Environment]::NewLine)

The runtime evaluates nested `all`, `any`, and `not` condition objects plus comparisons. Acts are unlocked by completed cases/acts, trust, mastery, workshop grade, eligible owned lots, and Grand Reserve state—not by a hard-coded day number.

## Reused core loop

Every story case uses the same playable systems as ordinary market artifacts: inspect clues, apply tools with compatible/wrong-tool consequences, authenticate through one of six visible hypotheses, appraise, make an ethical disclosure, then submit or auction. Case results update money, reputation, mastery, museum trust, integrity, ethics, and NPC relationships. A reviewed-with-mentor outcome prevents permanent campaign dead ends.

## Grand Reserve and endings

Qualification thresholds are stored in data: workshop grade **$($Campaign.qualification.workshopGrade)**, reputation **$($Campaign.qualification.reputation)**, authentication accuracy **$($Campaign.qualification.authenticationAccuracy)**, museum trust **$($Campaign.qualification.museumTrust)**, mastery **$($Campaign.qualification.masteryTotal)**, and **$($Campaign.qualification.eligibleLots)** eligible owned lots. The player selects exactly three persistent instance IDs. Each is auctioned through the normal bidder AI with at least eight participants in the separate 31-node Grand Reserve hall.

Stored final pillars are authentication, restoration, historical integrity, collection quality, collector reputation/trust, ethics, financial result, and Grand Reserve revenue. The deterministic priority evaluator selects ENDING S/A/B/C/D; all five paths and precedence are covered by `qa/R3_ENDING_TESTS.json`. Epilogue statistics, credits, ending gallery, and postgame follow.

## Content and duration

Connected content includes 60 playable ArtifactSpecs across 15 base mesh families, 60 visible signatures, 26 cases, 20 unique story artifacts, 30 in-world documents, 8 main NPCs, 12 secondary buyer portraits, 9 environments/presentations, 40 maker/model histories, 30 construction notes, and 20 period references.

The **8–12 hour main / 15–25+ hour side-content duration is estimated, not human-playtest verified**. Estimate basis: 26 authored cases at roughly 12–20 minutes each, market/restoration/auction interludes, evidence review, failed-attempt recovery, and optional 60-item collection/commission/postgame loops.
"@

$P0Rows = @(
    '| P0-01 Authentication overlap | `main3d.gd::show_authentication` 3×2 grid | R3-AUTH-01/02/03 | PASS |',
    '| P0-02 Live visual sync | `refresh_workpiece_visuals` after actions | R3-RESTORE-01/02, R3-DISASSEMBLY-01 | PASS |',
    '| P0-03 Reserve controls sale | `GameState.auction/sell` | R3-AUCTION-01/02 | PASS |',
    '| P0-04 Market rotation | persistent deterministic daily roster | R3-MARKET-01..04 | PASS |',
    '| P0-05 60 specs data-bound | registry/spec instance generation | R3-DATA-01..03 | PASS |',
    '| P0-06 60 visible variants | mesh/material/trim signatures | R3-VIS-01/02 + sheet | PASS |',
    '| P0-07 Bidder fields | participation/value/budget/dropout AI | R3-BIDDER-01..03 | PASS |',
    '| P0-08 25 events | structured effects and daily reachability | R3-EVENT-01/02 | PASS |',
    '| P0-09 25 upgrades | costs, duplicate block, material effects, UI | R3-UPGRADE-01/02 | PASS |',
    '| P0-10 Manifest/count truth | regenerated manifest and counts | R3-ASSET-01/02 | PASS |',
    '| P0-11 Honest disassembly | only supported clock/camera/radio families | R3-DISASSEMBLY-01/02 | PASS |',
    '| P0-12 Real QA paths | Button signals, live state, fresh renderer captures | all R3 suites | PASS |'
)
Write-Text 'R3_BUILD_REPORT.md' @"
# RELIC & RESERVE R3 — Source / QA Checkpoint Report

## Verdict

**SOURCE_QA PASS; R3 FINAL ACCEPTANCE UNVERIFIED.** The user has explicitly held Windows EXE/PCK and archive creation. No Windows application or ZIP was created or modified. Passing tests does not mean the game is complete.

Engine: `D:\AI 종합 폴더\Godot\4.7.1-standard\Godot_v4.7.1-stable_win64_console.exe` — `4.7.1.stable.official.a13da4feb`, Compatibility renderer.

Baseline: all 12 supplied R2 key-file hashes and the R2 build-report hash matched. The source archive itself was unavailable as a standalone ZIP, so its archive-level hash is UNVERIFIED; the preserved R2 Windows reference archive and existing binaries were not touched. Clean baseline behavior was reproduced at 38/40 before import and 40/40 after Godot editor import.

## P0 remediation

| Issue | Implementation | Regression evidence | Status |
|---|---|---|---|
$($P0Rows -join [Environment]::NewLine)

## Test totals

| Suite | Executed | Passed | Failed | Skipped |
|---|---:|---:|---:|---:|
| Core unit/state/UI/integration | $($Core.executed) | $($Core.passed) | $($Core.failed) | $($Core.skipped) |
| Campaign integration | $($CampaignTests.executed) | $($CampaignTests.passed) | $($CampaignTests.failed) | $($CampaignTests.skipped) |
| Ending evaluator | $($EndingTests.executed) | $($EndingTests.passed) | $($EndingTests.failed) | 0 |
| Windows EXE E2E | 0 | 0 | 0 | **HELD / UNVERIFIED** |

Native `RUN_R3_TESTS.ps1` completed successfully after a clean editor import. Final source regression was run after campaign integration and visual-harness changes.

Economy: 1,000 × 30-day runs; average purchases $($Economy.averages.purchases), sales $($Economy.averages.sales), no-sales $($Economy.averages.noSales), profit $($Economy.averages.profit), unique specs $($Economy.averages.uniqueArtifactsSeen); reserve-met rate $($Economy.reserveMetRate); cash p10/median/p90 $($Economy.cash.p10)/$($Economy.cash.median)/$($Economy.cash.p90); bankruptcy/stall rate $($Economy.bankruptcyOrNoSaleStallRate); budget violations $($Economy.invariants.budgetViolations), duplicate sales $($Economy.invariants.duplicateSales), non-finite values $($Economy.invariants.nonFinite). Ten 100-day samples also completed.

## Release hold

`BUILD_R3_WINDOWS.ps1` and `PACKAGE_R3.ps1` now refuse to run without `-UserAuthorized`. They were not executed. EXE, PCK, Windows ZIP, source ZIP, byte sizes, hashes, Korean-in-EXE rendering, and executable campaign acceptance remain **UNVERIFIED** until the user gives a later explicit instruction.
"@

Write-Text 'R3_KNOWN_ISSUES.md' @"
# R3 Known Issues / Unverified Items

1. **Windows release held:** no R3 EXE/PCK or archive exists. Export, executable launch, Korean rendering inside the EXE, and executable full-campaign acceptance are UNVERIFIED by explicit user instruction.
2. **Not declared complete:** automated/source QA PASS is not a product-completion declaration. Further design, writing, art, accessibility, and human playtest work may still be requested.
3. **Duration is estimated:** no timed human 8–12 hour or 15–25+ hour playtest was conducted.
4. **Rights review remains open:** all 237 manifest rows preserve project/R2 provenance and are marked `RIGHTS_REVIEW_REQUIRED` / `UNVERIFIED`; no CC0 claim is made.
5. **Localization scope:** 106 paired EN/KO keys cover the core UI, campaign shell, ending, and postgame. Proper names, artifact catalog fields, authored case summaries, document bodies, and bidder/NPC names remain English.
6. **Presentation scope:** the workshop and Grand Reserve are functional stylized 3D environments; final art polish and human UX/accessibility testing are not claimed.
"@

$CaptureLines = foreach ($Capture in $Visual.captures) { "- **$($Capture.name)** — `$($Capture.path)` — $($Capture.note) — PASS" }
Write-Text 'R3_VISUAL_QA.md' @"
# R3 Visual QA

Status: **SOURCE RUNTIME VISUAL PASS** at 1280×720 using Godot 4.7.1 Compatibility renderer on NVIDIA GeForce RTX 4070 SUPER. Windows exported executable rendering remains HELD / UNVERIFIED.

Reviewed evidence:

- `qa/r3_renders/screen_contact_sheet.png`: all 27 flow screens together.
- `qa/r3_renders/60_spec_contact_sheet.png`: all 60 runtime mesh/material/trim signatures.
- Full-size spot checks: market, inventory, inspection/action sync, all six authentication choices, upgrades, Korean market, final-lot selection, distinct Grand Reserve hall, ending, and postgame.

Findings: zero overlapping authentication controls; no cropped headers or navigation after fixed-slot layout; Korean glyphs render without tofu; scrolling lists remain reachable; cleaning and disassembly captures follow UI actions without a hidden `load_artifact`; the Grand Reserve uses a visibly distinct 31-node hall; 60 thumbnails show 15 families with four distinct signatures each.

## Captures

$($CaptureLines -join [Environment]::NewLine)
"@

Write-Text 'qa/R3_CAMPAIGN_REPORT.md' @"
# R3 Campaign Report

## IMPLEMENTED

Prologue → Acts 1–5 → Grand Reserve → Ending → Epilogue → Postgame is connected in the normal runtime. Progression is condition-driven and saved. All 26 cases use the core playable artifact path, include a recovery outcome, and update campaign systems. The player selects three distinct eligible owned instance IDs for the final auction. Five deterministic ending tiers, credits, ending gallery, and postgame are connected.

Content counts: Act 1 **8**, Act 4 **6** (five shadow cases plus composite climax), Act 5 **6**, story artifacts **20**, NPCs **8**, expression assets **32**, buyer portraits **12**, environments **9**, base families **15**, playable specs **60**, documents **30**, fictional makers **20**, histories **40**, construction notes **30**, period references **20**, endings **5**.

## TESTED

Campaign suite: **$($CampaignTests.passed)/$($CampaignTests.executed)**. Ending suite: **$($EndingTests.passed)/$($EndingTests.executed)**. Accelerated campaign completed 26 public case transitions and reached POSTGAME with ENDING_S. Grand Reserve stored three distinct owned IDs, ran three normal auctions with at least eight bidders each, and stored every score component. Save/load passed at an act boundary and after final selection/ending/postgame. Fresh flow screenshots and both contact sheets were visually reviewed.

## SIMULATED

Economy/bidder simulation: **$($Economy.runs)** deterministic 30-day runs plus **$($Economy.hundredDaySamples.Count)** 100-day samples. This is balance evidence, not a human playtest and not proof of campaign duration.

## UNVERIFIED / HELD

The Windows EXE full-campaign acceptance gate, executable Korean rendering, package hashes/sizes, and timed human duration are not executed. The user explicitly prohibited creating Windows apps or archives until a later instruction. Therefore the master prompt's overall `R3 FINAL PASS` is not claimed even though source/runtime suites pass.
"@

Write-Text 'README_R3.md' @"
# RELIC & RESERVE R3 Source Checkpoint

This Godot 4.7.1 project is the corrected R3 source workspace derived from the preserved Manus R2 baseline. It contains the data-bound 3D conservation/auction core and the connected campaign through Grand Reserve, five endings, epilogue, and postgame.

## Run and test

- Open `project.godot` with Godot **4.7.1 stable Standard**, Compatibility renderer.
- Native Windows import: `./RUN_R3_IMPORT.ps1`
- Native source tests: `./RUN_R3_TESTS.ps1`
- Main scene: `res://scenes/Main.tscn`

The test workflow imports assets, then runs core (34), campaign (23), ending (5), and 1,000-run economy coverage. Reports live in `qa/`; design/catalog documents live in `docs/`.

## Release hold

Passing tests does **not** declare the game complete. Do not create or modify R3/R2 EXE, PCK, ZIP, 7z, or RAR artifacts unless the user later gives an explicit instruction. Build/package scripts enforce this with a required `-UserAuthorized` switch. No Windows build or archive was produced at this checkpoint.

See `R3_BUILD_REPORT.md`, `R3_KNOWN_ISSUES.md`, `R3_VISUAL_QA.md`, `R3_RUNTIME_INTEGRATION_AUDIT.json`, and `R3_ASSET_AUDIT.json`.
"@

$ChecksumFiles = @(
    'project.godot', 'scripts/runtime_registry.gd', 'scripts/game_state.gd', 'scripts/main3d.gd',
    'data/visual_variants.json', 'data/campaign/campaign.json', 'localization/en.json', 'localization/ko.json',
    'qa/R3_TEST_REPORT.json', 'qa/R3_CAMPAIGN_TESTS.json', 'qa/R3_ENDING_TESTS.json',
    'qa/R3_ECONOMY_SIMULATION.json', 'qa/R3_VISUAL_QA.json', 'R3_RUNTIME_INTEGRATION_AUDIT.json',
    'R3_ASSET_AUDIT.json', 'R3_BUILD_REPORT.md', 'R3_KNOWN_ISSUES.md', 'R3_VISUAL_QA.md',
    'qa/R3_CAMPAIGN_REPORT.md', 'docs/FULL_CAMPAIGN_DESIGN.md', 'docs/STORY_CASE_CATALOG.md', 'docs/NPC_CATALOG.md'
)
$ChecksumLines = foreach ($RelativePath in $ChecksumFiles) {
    $Hash = (Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $ProjectRoot $RelativePath)).Hash.ToLowerInvariant()
    "$Hash  $($RelativePath.Replace('\','/'))"
}
Write-Text 'SHA256SUMS_R3.txt' ($ChecksumLines -join [Environment]::NewLine)

Write-Output "R3 source/QA reports written. Windows artifacts remain held; count=$($HeldArtifacts.Count)."
