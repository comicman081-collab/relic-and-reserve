# RELIC & RESERVE R3 — Source / QA Checkpoint Report

## Verdict

**SOURCE_QA PASS; R3 FINAL ACCEPTANCE UNVERIFIED.** The user has explicitly held Windows EXE/PCK and archive creation. No Windows application or ZIP was created or modified. Passing tests does not mean the game is complete.

Engine: D:\AI 종합 폴더\Godot\4.7.1-standard\Godot_v4.7.1-stable_win64_console.exe — 4.7.1.stable.official.a13da4feb, Compatibility renderer.

Baseline: all 12 supplied R2 key-file hashes and the R2 build-report hash matched. The source archive itself was unavailable as a standalone ZIP, so its archive-level hash is UNVERIFIED; the preserved R2 Windows reference archive and existing binaries were not touched. Clean baseline behavior was reproduced at 38/40 before import and 40/40 after Godot editor import.

## P0 remediation

| Issue | Implementation | Regression evidence | Status |
|---|---|---|---|
| P0-01 Authentication overlap | `main3d.gd::show_authentication` 3×2 grid | R3-AUTH-01/02/03 | PASS |
| P0-02 Live visual sync | `refresh_workpiece_visuals` after actions | R3-RESTORE-01/02, R3-DISASSEMBLY-01 | PASS |
| P0-03 Reserve controls sale | `GameState.auction/sell` | R3-AUCTION-01/02 | PASS |
| P0-04 Market rotation | persistent deterministic daily roster | R3-MARKET-01..04 | PASS |
| P0-05 60 specs data-bound | registry/spec instance generation | R3-DATA-01..03 | PASS |
| P0-06 60 visible variants | mesh/material/trim signatures | R3-VIS-01/02 + sheet | PASS |
| P0-07 Bidder fields | participation/value/budget/dropout AI | R3-BIDDER-01..03 | PASS |
| P0-08 25 events | structured effects and daily reachability | R3-EVENT-01/02 | PASS |
| P0-09 25 upgrades | costs, duplicate block, material effects, UI | R3-UPGRADE-01/02 | PASS |
| P0-10 Manifest/count truth | regenerated manifest and counts | R3-ASSET-01/02 | PASS |
| P0-11 Honest disassembly | only supported clock/camera/radio families | R3-DISASSEMBLY-01/02 | PASS |
| P0-12 Real QA paths | Button signals, live state, fresh renderer captures | all R3 suites | PASS |

## Test totals

| Suite | Executed | Passed | Failed | Skipped |
|---|---:|---:|---:|---:|
| Core unit/state/UI/integration | 34 | 34 | 0 | 0 |
| Campaign integration | 23 | 23 | 0 | 0 |
| Ending evaluator | 5 | 5 | 0 | 0 |
| Windows EXE E2E | 0 | 0 | 0 | **HELD / UNVERIFIED** |

Native RUN_R3_TESTS.ps1 completed successfully after a clean editor import. Final source regression was run after campaign integration and visual-harness changes.

Economy: 1,000 × 30-day runs; average purchases 29.985, sales 27.873, no-sales 2.127, profit 2507.143, unique specs 60; reserve-met rate 0.9291; cash p10/median/p90 3230/4341/5414; bankruptcy/stall rate 0; budget violations 0, duplicate sales 0, non-finite values 0. Ten 100-day samples also completed.

## Release hold

BUILD_R3_WINDOWS.ps1 and PACKAGE_R3.ps1 now refuse to run without -UserAuthorized. They were not executed. EXE, PCK, Windows ZIP, source ZIP, byte sizes, hashes, Korean-in-EXE rendering, and executable campaign acceptance remain **UNVERIFIED** until the user gives a later explicit instruction.
