# RELIC & RESERVE R3 — Full Campaign Design

## Campaign spine

| Stage | Title | Presentation/location | Cases | Unlock source |
|---|---|---|---:|---|
| `PROLOGUE` | The Closed Workshop | `small_workshop` | 1 | condition object in data/campaign/campaign.json |
| `ACT_1` | The Local Circuit | `local_market` | 8 | condition object in data/campaign/campaign.json |
| `ACT_2` | Provenance | `archive_room` | 3 | condition object in data/campaign/campaign.json |
| `ACT_3` | The Collectors | `collector_home` | 2 | condition object in data/campaign/campaign.json |
| `ACT_4` | The Forger's Shadow | `premium_showroom` | 6 | condition object in data/campaign/campaign.json |
| `ACT_5` | Master Conservator | `museum_room` | 6 | condition object in data/campaign/campaign.json |
| `GRAND_RESERVE` | The Grand Reserve | `grand_reserve_hall` | 0 | condition object in data/campaign/campaign.json |
| `EPILOGUE` | Epilogue | `upgraded_workshop` | 0 | condition object in data/campaign/campaign.json |
| `POSTGAME` | Endless Workshop | `upgraded_workshop` | 0 | condition object in data/campaign/campaign.json |

The runtime evaluates nested ll, ny, and 
ot condition objects plus comparisons. Acts are unlocked by completed cases/acts, trust, mastery, workshop grade, eligible owned lots, and Grand Reserve state—not by a hard-coded day number.

## Reused core loop

Every story case uses the same playable systems as ordinary market artifacts: inspect clues, apply tools with compatible/wrong-tool consequences, authenticate through one of six visible hypotheses, appraise, make an ethical disclosure, then submit or auction. Case results update money, reputation, mastery, museum trust, integrity, ethics, and NPC relationships. A reviewed-with-mentor outcome prevents permanent campaign dead ends.

## Grand Reserve and endings

Qualification thresholds are stored in data: workshop grade **5**, reputation **45**, authentication accuracy **0.6**, museum trust **24**, mastery **42**, and **3** eligible owned lots. The player selects exactly three persistent instance IDs. Each is auctioned through the normal bidder AI with at least eight participants in the separate 31-node Grand Reserve hall.

Stored final pillars are authentication, restoration, historical integrity, collection quality, collector reputation/trust, ethics, financial result, and Grand Reserve revenue. The deterministic priority evaluator selects ENDING S/A/B/C/D; all five paths and precedence are covered by qa/R3_ENDING_TESTS.json. Epilogue statistics, credits, ending gallery, and postgame follow.

## Content and duration

Connected content includes 60 playable ArtifactSpecs across 15 base mesh families, 60 visible signatures, 26 cases, 20 unique story artifacts, 30 in-world documents, 8 main NPCs, 12 secondary buyer portraits, 9 environments/presentations, 40 maker/model histories, 30 construction notes, and 20 period references.

The **8–12 hour main / 15–25+ hour side-content duration is estimated, not human-playtest verified**. Estimate basis: 26 authored cases at roughly 12–20 minutes each, market/restoration/auction interludes, evidence review, failed-attempt recovery, and optional 60-item collection/commission/postgame loops.
