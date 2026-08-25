# R3 Campaign Report

## IMPLEMENTED

Prologue → Acts 1–5 → Grand Reserve → Ending → Epilogue → Postgame is connected in the normal runtime. Progression is condition-driven and saved. All 26 cases use the core playable artifact path, include a recovery outcome, and update campaign systems. The player selects three distinct eligible owned instance IDs for the final auction. Five deterministic ending tiers, credits, ending gallery, and postgame are connected.

Content counts: Act 1 **8**, Act 4 **6** (five shadow cases plus composite climax), Act 5 **6**, story artifacts **20**, NPCs **8**, expression assets **32**, buyer portraits **12**, environments **9**, base families **15**, playable specs **60**, documents **30**, fictional makers **20**, histories **40**, construction notes **30**, period references **20**, endings **5**.

## TESTED

Campaign suite: **23/23**. Ending suite: **5/5**. Accelerated campaign completed 26 public case transitions and reached POSTGAME with ENDING_S. Grand Reserve stored three distinct owned IDs, ran three normal auctions with at least eight bidders each, and stored every score component. Save/load passed at an act boundary and after final selection/ending/postgame. Fresh flow screenshots and both contact sheets were visually reviewed.

M1 integrity suite: **12/12**. Prologue Golden Case suite: **10/10**. Core regression suite after integration: **36/36**. The authored-v2 runtime currently covers **1/26** campaign cases (`prologue_clock`); the other 25 remain playable legacy/projection cases and are not claimed as finished authored investigations. See `docs/R3_AUTHORED_CASE_ROADMAP.md`.

## SIMULATED

Economy/bidder simulation: **1000** deterministic 30-day runs plus **10** 100-day samples. This is balance evidence, not a human playtest and not proof of campaign duration.

## UNVERIFIED / HELD

Human campaign pacing/comprehension, complete authored-v2 migration, the Windows EXE full-campaign acceptance gate, executable Korean rendering, package hashes/sizes, and timed human duration are not executed. The user explicitly prohibited creating Windows apps or archives until a later instruction. Therefore the master prompt's overall R3 FINAL PASS is not claimed even though current source/runtime suites pass.
