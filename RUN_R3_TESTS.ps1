$ErrorActionPreference = 'Stop'
$ProjectRoot = $PSScriptRoot
$GodotExe = & (Join-Path $ProjectRoot 'tools\Find-Godot471.ps1')
$PreviousAppData = $env:APPDATA
$PreviousLocalAppData = $env:LOCALAPPDATA
$SystemTempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
$TestUserHome = [IO.Path]::GetFullPath((Join-Path $SystemTempRoot ("relic-reserve-r3-tests-" + [Guid]::NewGuid().ToString('N'))))
$ResolvedTestUserHome = $TestUserHome.TrimEnd('\') + '\'
if (-not $ResolvedTestUserHome.StartsWith($SystemTempRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to create an isolated Godot test home outside the system temp directory: $ResolvedTestUserHome"
}
[void](New-Item -ItemType Directory -Path $TestUserHome -Force)
# Godot 4.7 on Windows resolves user:// below %APPDATA%\Godot. The
# GODOT_USER_HOME variable is not honored by this editor build, so isolate the
# spawned validator processes through temporary APPDATA/LOCALAPPDATA roots instead.
$env:APPDATA = $TestUserHome
$env:LOCALAPPDATA = $TestUserHome

try {
& (Join-Path $ProjectRoot 'RUN_R3_IMPORT.ps1')

function Resolve-PythonInvocation {
    $DirectCandidates = @(
        (Get-Command 'python.exe' -ErrorAction SilentlyContinue),
        (Get-Command 'python3.exe' -ErrorAction SilentlyContinue)
    ) | Where-Object { $null -ne $_ }
    foreach ($Candidate in $DirectCandidates) {
        & $Candidate.Source --version *> $null
        if ($LASTEXITCODE -eq 0) {
            return @{ Exe = $Candidate.Source; PrefixArgs = @() }
        }
    }

    $PyLauncher = Get-Command 'py.exe' -ErrorAction SilentlyContinue
    if ($null -ne $PyLauncher) {
        & $PyLauncher.Source -3 --version *> $null
        if ($LASTEXITCODE -eq 0) {
            return @{ Exe = $PyLauncher.Source; PrefixArgs = @('-3') }
        }
    }

    # Codex Desktop includes a private Python runtime that is intentionally not
    # added to PATH. Use it only as a validated local fallback; ordinary clones
    # continue to prefer their system Python above.
    $BundledPython = Join-Path $env:USERPROFILE '.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
    if (Test-Path -LiteralPath $BundledPython -PathType Leaf) {
        & $BundledPython --version *> $null
        if ($LASTEXITCODE -eq 0) {
            return @{ Exe = $BundledPython; PrefixArgs = @() }
        }
    }
    throw 'Python 3 is required for the R3 static validators, but no working local interpreter was found.'
}

$PythonInvocation = Resolve-PythonInvocation
$PythonLauncher = [string]$PythonInvocation.Exe
$PythonPrefixArgs = @($PythonInvocation.PrefixArgs)
$Validators = @(
    'tools\validators\validate_stage_mvp.py',
    'tools\validators\validate_character_portraits.py',
    'tools\validators\validate_authored_cases.py'
)

function Test-JsonProperty {
    param(
        [Parameter(Mandatory = $true)]$Object,
        [Parameter(Mandatory = $true)][string]$Name
    )

    return $null -ne $Object.PSObject.Properties[$Name]
}

function Assert-FreshFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][DateTime]$StartedAtUtc,
        [Parameter(Mandatory = $true)][string]$Description
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "$Description was not created: $Path"
    }

    $WrittenAtUtc = (Get-Item -LiteralPath $Path).LastWriteTimeUtc
    if ($WrittenAtUtc -lt $StartedAtUtc.AddSeconds(-1)) {
        throw "$Description is stale ($WrittenAtUtc UTC, suite started $StartedAtUtc UTC): $Path"
    }
}

function Assert-CountReport {
    param(
        [Parameter(Mandatory = $true)]$Report,
        [Parameter(Mandatory = $true)][string]$ReportPath
    )

    foreach ($RequiredProperty in @('executed', 'passed', 'failed')) {
        if (-not (Test-JsonProperty -Object $Report -Name $RequiredProperty)) {
            throw "R3 report lacks '$RequiredProperty': $ReportPath"
        }
    }

    $Executed = [int]$Report.executed
    $Passed = [int]$Report.passed
    $Failed = [int]$Report.failed
    if ($Executed -le 0 -or $Passed -ne $Executed -or $Failed -ne 0) {
        throw "R3 report is not a full pass (executed=$Executed, passed=$Passed, failed=$Failed): $ReportPath"
    }

    if ((Test-JsonProperty -Object $Report -Name 'skipped') -and [int]$Report.skipped -ne 0) {
        throw "R3 report contains skipped tests (skipped=$($Report.skipped)): $ReportPath"
    }
}

function Assert-EconomyReport {
    param(
        [Parameter(Mandatory = $true)]$Report,
        [Parameter(Mandatory = $true)][string]$ReportPath
    )

    foreach ($RequiredProperty in @('passed', 'runs', 'commissionAttempts', 'invariants')) {
        if (-not (Test-JsonProperty -Object $Report -Name $RequiredProperty)) {
            throw "Economy report lacks '$RequiredProperty': $ReportPath"
        }
    }

    if (-not [bool]$Report.passed -or [int]$Report.runs -le 0 -or [int]$Report.commissionAttempts -le 0) {
        throw "Economy simulation did not execute and pass: $ReportPath"
    }

    foreach ($Invariant in @('nonFinite', 'budgetViolations', 'duplicateSales', 'commissionFailures')) {
        if (-not (Test-JsonProperty -Object $Report.invariants -Name $Invariant) -or [int]$Report.invariants.$Invariant -ne 0) {
            throw "Economy invariant '$Invariant' is missing or non-zero: $ReportPath"
        }
    }
}

foreach ($Validator in $Validators) {
    & $PythonLauncher @PythonPrefixArgs (Join-Path $ProjectRoot $Validator)
    if ($LASTEXITCODE -ne 0) {
        throw "R3 validator failed: $Validator"
    }
}

# Audit-only human-session harness schema smoke test. This fixture is deliberately
# not human evidence; it proves that public-safe Stage 1/5/8/10 records validate
# without loading production state, consuming RNG, or changing the game.
$HumanHarness = Join-Path $ProjectRoot 'tools\audit\human_session_harness.py'
$HumanHarnessFixture = Join-Path $ProjectRoot 'qa\human_sessions\fixture_public_schema.jsonl'
$HumanHarnessReport = Join-Path $ProjectRoot 'qa\human_sessions\fixture_public_schema.report.json'
& $PythonLauncher @PythonPrefixArgs $HumanHarness --input $HumanHarnessFixture --output $HumanHarnessReport
if ($LASTEXITCODE -ne 0) {
    throw "Audit-only human-session harness fixture failed: $HumanHarness"
}
try {
    $HarnessReport = Get-Content -Raw -LiteralPath $HumanHarnessReport | ConvertFrom-Json
}
catch {
    throw "Audit-only human-session harness report is not valid JSON: $HumanHarnessReport. $($_.Exception.Message)"
}
if (-not [bool]$HarnessReport.passed -or $HarnessReport.status -ne 'FIXTURE_PASS_NOT_HUMAN_EVIDENCE' -or [int]$HarnessReport.productionMutations -ne 0 -or [int]$HarnessReport.rngConsumption -ne 0) {
    throw "Audit-only human-session harness did not preserve its read-only contract: $HumanHarnessReport"
}
Write-Output "PASS $HumanHarness"

$Suites = @(
    @{ Script = 'res://tests/r3_core_tests.gd'; Log = 'qa\R3_CORE_TESTS.log'; Report = 'qa\R3_TEST_REPORT.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_campaign_tests.gd'; Log = 'qa\R3_CAMPAIGN_TESTS.log'; Report = 'qa\R3_CAMPAIGN_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_integrity_tests.gd'; Log = 'qa\R3_INTEGRITY_TESTS.log'; Report = 'qa\R3_INTEGRITY_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_save_crash_tests.gd'; Log = 'qa\R3_SAVE_CRASH_TESTS.log'; Report = 'qa\R3_SAVE_CRASH_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_stage_runtime_tests.gd'; Log = 'qa\R3_STAGE_RUNTIME_TESTS.log'; Report = 'qa\R3_STAGE_RUNTIME_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_stage_telemetry_tests.gd'; Log = 'qa\R3_STAGE_TELEMETRY_TESTS.log'; Report = 'qa\R3_STAGE_TELEMETRY_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_authored_pressure_runtime_tests.gd'; Log = 'qa\R3_AUTHORED_PRESSURE_RUNTIME_TESTS.log'; Report = 'qa\R3_AUTHORED_PRESSURE_RUNTIME_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_stage_replay_feedback_tests.gd'; Log = 'qa\R3_STAGE_REPLAY_FEEDBACK_TESTS.log'; Report = 'qa\R3_STAGE_REPLAY_FEEDBACK_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_stage_replay_ui_tests.gd'; Log = 'qa\R3_STAGE_REPLAY_UI_TESTS.log'; Report = 'qa\R3_STAGE_REPLAY_UI_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_stage10_handoff_tests.gd'; Log = 'qa\R3_STAGE10_HANDOFF_TESTS.log'; Report = 'qa\R3_STAGE10_HANDOFF_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_stage10_artifact_identity_tests.gd'; Log = 'qa\R3_STAGE10_ARTIFACT_IDENTITY_TESTS.log'; Report = 'qa\R3_STAGE10_ARTIFACT_IDENTITY_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_stage2_authored_cases_tests.gd'; Log = 'qa\R3_STAGE2_AUTHORED_CASES_TESTS.log'; Report = 'qa\R3_STAGE2_AUTHORED_CASES_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_stage3_authored_cases_tests.gd'; Log = 'qa\R3_STAGE3_AUTHORED_CASES_TESTS.log'; Report = 'qa\R3_STAGE3_AUTHORED_CASES_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_stage4_authored_cases_tests.gd'; Log = 'qa\R3_STAGE4_AUTHORED_CASES_TESTS.log'; Report = 'qa\R3_STAGE4_AUTHORED_CASES_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_stage5_authored_cases_tests.gd'; Log = 'qa\R3_STAGE5_AUTHORED_CASES_TESTS.log'; Report = 'qa\R3_STAGE5_AUTHORED_CASES_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_stage5_visual_identity_tests.gd'; Log = 'qa\R3_STAGE5_VISUAL_IDENTITY_TESTS.log'; Report = 'qa\R3_STAGE5_VISUAL_IDENTITY_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_stage6_authored_cases_tests.gd'; Log = 'qa\R3_STAGE6_AUTHORED_CASES_TESTS.log'; Report = 'qa\R3_STAGE6_AUTHORED_CASES_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_stage6_economy_tests.gd'; Log = 'qa\R3_STAGE6_ECONOMY_TESTS.log'; Report = 'qa\R3_STAGE6_ECONOMY_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_stage6_visual_identity_tests.gd'; Log = 'qa\R3_STAGE6_VISUAL_IDENTITY_TESTS.log'; Report = 'qa\R3_STAGE6_VISUAL_IDENTITY_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_stage7_authored_cases_tests.gd'; Log = 'qa\R3_STAGE7_AUTHORED_CASES_TESTS.log'; Report = 'qa\R3_STAGE7_AUTHORED_CASES_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_stage7_economy_tests.gd'; Log = 'qa\R3_STAGE7_ECONOMY_TESTS.log'; Report = 'qa\R3_STAGE7_ECONOMY_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_stage7_visual_identity_tests.gd'; Log = 'qa\R3_STAGE7_VISUAL_IDENTITY_TESTS.log'; Report = 'qa\R3_STAGE7_VISUAL_IDENTITY_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_authored_outcome_rules_tests.gd'; Log = 'qa\R3_AUTHORED_OUTCOME_RULES_TESTS.log'; Report = 'qa\R3_AUTHORED_OUTCOME_RULES_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_authored_presentation_metadata_tests.gd'; Log = 'qa\R3_AUTHORED_PRESENTATION_METADATA_TESTS.log'; Report = 'qa\R3_AUTHORED_PRESENTATION_METADATA_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_authored_case_state_migration_tests.gd'; Log = 'qa\R3_AUTHORED_CASE_STATE_MIGRATION_TESTS.log'; Report = 'qa\R3_AUTHORED_CASE_STATE_MIGRATION_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_authored_bookend_cases_tests.gd'; Log = 'qa\R3_AUTHORED_BOOKEND_CASES_TESTS.log'; Report = 'qa\R3_AUTHORED_BOOKEND_CASES_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_final_journey_ui_tests.gd'; Log = 'qa\R3_FINAL_JOURNEY_UI_TESTS.log'; Report = 'qa\R3_FINAL_JOURNEY_UI_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_repeated_core_ui_tests.gd'; Log = 'qa\R3_REPEATED_CORE_UI_TESTS.log'; Report = 'qa\R3_REPEATED_CORE_UI_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_grand_reserve_live_auction_tests.gd'; Log = 'qa\R3_GRAND_RESERVE_LIVE_AUCTION_TESTS.log'; Report = 'qa\R3_GRAND_RESERVE_LIVE_AUCTION_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_tutorial_crash_recovery_tests.gd'; Log = 'qa\R3_TUTORIAL_CRASH_RECOVERY_TESTS.log'; Report = 'qa\R3_TUTORIAL_CRASH_RECOVERY_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_golden_case_tests.gd'; Log = 'qa\R3_GOLDEN_CASE_TESTS.log'; Report = 'qa\R3_GOLDEN_CASE_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_false_invoice_tests.gd'; Log = 'qa\R3_FALSE_INVOICE_TESTS.log'; Report = 'qa\R3_FALSE_INVOICE_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_shadow_camera_tests.gd'; Log = 'qa\R3_SHADOW_CAMERA_TESTS.log'; Report = 'qa\R3_SHADOW_CAMERA_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_mvp_policy_tests.gd'; Log = 'qa\R3_MVP_POLICY_TESTS.log'; Report = 'qa\R3_MVP_POLICY_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_illustrated_case_ui_tests.gd'; Log = 'qa\R3_ILLUSTRATED_CASE_UI_TESTS.log'; Report = 'qa\R3_ILLUSTRATED_CASE_UI_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_portrait_dialogue_ui_tests.gd'; Log = 'qa\R3_PORTRAIT_DIALOGUE_UI_TESTS.log'; Report = 'qa\R3_PORTRAIT_DIALOGUE_UI_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_character_reaction_ui_tests.gd'; Log = 'qa\R3_CHARACTER_REACTION_UI_TESTS.log'; Report = 'qa\R3_CHARACTER_REACTION_UI_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_pending_auction_ui_tests.gd'; Log = 'qa\R3_PENDING_AUCTION_UI_TESTS.log'; Report = 'qa\R3_PENDING_AUCTION_UI_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_event_ui_tests.gd'; Log = 'qa\R3_EVENT_UI_TESTS.log'; Report = 'qa\R3_EVENT_UI_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_listing_ui_tests.gd'; Log = 'qa\R3_LISTING_UI_TESTS.log'; Report = 'qa\R3_LISTING_UI_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_auction_balance_tests.gd'; Log = 'qa\R3_AUCTION_BALANCE_TESTS.log'; Report = 'qa\R3_AUCTION_BALANCE_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_stage_pressure_baseline.gd'; Log = 'qa\R3_STAGE_PRESSURE_BASELINE.log'; Report = 'qa\R3_STAGE_PRESSURE_BASELINE.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_tutorial_ui_tests.gd'; Log = 'qa\R3_TUTORIAL_UI_TESTS.log'; Report = 'qa\R3_TUTORIAL_UI_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_product_direction_ui_tests.gd'; Log = 'qa\R3_PRODUCT_DIRECTION_UI_TESTS.log'; Report = 'qa\R3_PRODUCT_DIRECTION_UI_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/capture_latest_runtime_viewport.gd'; Log = 'qa\R3_VIEWPORT_DENSITY_TESTS.log'; Report = 'qa\R3_VIEWPORT_DENSITY_TESTS.json'; Mode = 'Counts' },
    @{ Script = 'res://tests/r3_economy_simulation.gd'; Log = 'qa\R3_ECONOMY_SIMULATION.log'; Report = 'qa\R3_ECONOMY_SIMULATION.json'; Mode = 'Economy' }
)

foreach ($Suite in $Suites) {
    $LogPath = Join-Path $ProjectRoot $Suite.Log
    $ReportPath = Join-Path $ProjectRoot $Suite.Report
    # A Godot --script parse failure can still return process exit code 0. Remove
    # only this suite's generated evidence first so stale PASS files cannot mask
    # a script that never executed.
    foreach ($GeneratedPath in @($LogPath, $ReportPath)) {
        $FullGeneratedPath = [IO.Path]::GetFullPath($GeneratedPath)
        $FullProjectRoot = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd('\') + '\'
        if (-not $FullGeneratedPath.StartsWith($FullProjectRoot, [StringComparison]::OrdinalIgnoreCase)) {
            throw "Refusing to reset generated evidence outside the project: $FullGeneratedPath"
        }
        if (Test-Path -LiteralPath $FullGeneratedPath -PathType Leaf) {
            Remove-Item -LiteralPath $FullGeneratedPath -Force
        }
    }
    $SuiteStartedAtUtc = [DateTime]::UtcNow
    & $GodotExe --headless --log-file $LogPath --path $ProjectRoot --script $Suite.Script
    if ($LASTEXITCODE -ne 0) {
        throw "R3 suite failed: $($Suite.Script). See $LogPath"
    }

    Assert-FreshFile -Path $LogPath -StartedAtUtc $SuiteStartedAtUtc -Description 'R3 suite log'
    $FatalDiagnostics = @(Select-String -LiteralPath $LogPath -Pattern '^\s*(SCRIPT ERROR:|ERROR:)|Failed to load script' -CaseSensitive:$false)
    if ($FatalDiagnostics.Count -gt 0) {
        $DiagnosticPreview = ($FatalDiagnostics | Select-Object -First 5 | ForEach-Object { $_.Line.Trim() }) -join ' | '
        throw "R3 suite emitted fatal diagnostics despite exit code 0: $($Suite.Script). $DiagnosticPreview"
    }

    Assert-FreshFile -Path $ReportPath -StartedAtUtc $SuiteStartedAtUtc -Description 'R3 suite report'
    try {
        $Report = Get-Content -Raw -LiteralPath $ReportPath | ConvertFrom-Json
    }
    catch {
        throw "R3 suite report is not valid JSON: $ReportPath. $($_.Exception.Message)"
    }

    if ($Suite.Mode -eq 'Economy') {
        Assert-EconomyReport -Report $Report -ReportPath $ReportPath
    }
    else {
        Assert-CountReport -Report $Report -ReportPath $ReportPath
    }
    Write-Output "PASS $($Suite.Script)"
}

Write-Output 'R3 tests PASS — audit-only human-session public-safe harness, stage/portrait static validators, core, campaign, M1 integrity, run/profile crash injection plus tutorial run/profile recovery, ten-stage runtime and public Stage summaries, save-v6 exactly-once Stage telemetry with frozen public pressure feedback, Stage 1/5/10 authored-risk and repair-tool diversity contracts, public-only anti-gaming three-axis runtime feedback plus illustrated Stage replay UI, persistent three-lot Grand Reserve live auction and Stage 10 clear-to-ending handoff, card-driven low-text Inventory/Authentication/Upgrades flows, six-step contextual tutorial guidance, three authored-v2 contrast cases, illustrated/authentication UI, portrait/event dialogue UI with bounded child-only micro-reactions, authoritative pending-auction freeze/exactly-once cue recovery, two-step listing, calibrated auction balance and causal-reason UI, strict-headless 1280x720 viewport density, visible-policy gate, endings, and economy simulation.'
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
    $CleanupPath = [IO.Path]::GetFullPath($TestUserHome).TrimEnd('\') + '\'
    if (-not $CleanupPath.StartsWith($SystemTempRoot, [StringComparison]::OrdinalIgnoreCase)) {
        throw "Refusing to remove a test home outside the system temp directory: $CleanupPath"
    }
    if (Test-Path -LiteralPath $TestUserHome -PathType Container) {
        Remove-Item -LiteralPath $TestUserHome -Recurse -Force
    }
}
