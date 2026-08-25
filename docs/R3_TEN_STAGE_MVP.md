# RELIC & RESERVE — Ten-Stage MVP Contract

Status date: 2026-08-24 (Asia/Seoul)

This contract incorporates the expanded MVP decisions agreed with the user and reviewed through GPT web collaboration. It does not declare the game complete or lift the Windows/archive release hold.

## Act and Stage have different jobs

- **Act** remains the canonical story structure: Prologue → Acts 1–5 → Grand Reserve → Ending/Epilogue/Postgame.
- **Stage** is the persistent progression, difficulty and artifact-unlock layer above that story.
- The 26 existing cases keep their order and Act membership. Stage definitions reference contiguous portions of that order and never duplicate or reorder cases.
- Stage 1 begins with the Prologue. Stage 10 includes the late Act 5 cases and Grand Reserve. Ending/Postgame follow Stage 10 and are not an eleventh stage.

The sixteen authored-v2 cases remain in their canonical campaign locations. They are quality references for all stage content, not cases artificially regrouped into Stage 1.

## Ten data-driven stages

Each `StageDefinition` contains:

- `stage_id`: integer 1–10
- localized title and compact visual summary
- `case_ids`: canonical contiguous campaign case IDs
- `introduced_artifact_ids`: exactly two new ArtifactSpec IDs
- `difficulty_multiplier`: `pow(1.07, stage_id - 1)`
- final-stage Grand Reserve marker where applicable

Stage 1 has multiplier `1.0`; Stage 10 is approximately `1.838459`.

## Completion and performance are separate contracts

Every stage now carries two compact data records. They must never be collapsed into one gate.

`completion_contract` preserves the existing authoritative route:

- all case IDs scoped by the stage must be completed;
- the existing `includes_grand_reserve` flag determines whether the final reserve event is also required;
- completion persistently records the clear and unlocks the next stage where one exists;
- a replay or lower score never relocks progress.

`performance_target` is advisory feedback after or during that run. It consumes one generic `public_stage_score`, compares it with `GTE`, selects the highest reached grade threshold and displays localized goal, target-miss and advice labels. Target scores rise monotonically from 55 at Stage 1 to 64 at Stage 10. A target miss can change feedback and the stored best score only; it cannot change completion, unlock, clear history, ending access or replay access.

The score is deterministic from player-visible run facts. For ordinary stages it is the mean of visible case outcome tiers already used by the generic stage scoring path. For the last stage it is the visible Grand Reserve balanced score. The contract permits only public outcome-tier counts, scoped case count and the public balanced result as inputs. Canonical answers, private value, unrevealed evidence, internal truth fields and RNG state are not inputs.

Four localized grade labels are shared by all stages: Developing, Target Met, Expert and Master. Per-stage threshold arrays contain numbers and grade IDs only; there are no scripts, callbacks, formulas or stage-specific handlers in a stage row.

### Runtime/UI integration API

The later runtime wire should expose one generic read API, equivalent to:

```text
get_stage_public_summary(stage_id = current)
  -> stageId
     status
     completedCaseCount / totalCaseCount
     grandReserveRequired / grandReserveComplete
     publicStageScore                 # 0..100, deterministic public stats only
     targetScore / targetMet
     gradeId
```

The evaluator reads `RuntimeRegistry.get_stage_definition(stage_id)`, applies the declared comparator and walks the sorted thresholds. UI localization reads the returned grade ID plus the localized labels already in stage data. It must not branch on a stage number, case ID or artifact ID.

Completion remains owned by the existing `stage_objectives_complete → complete_stage` path. The performance evaluator runs for display and best-score comparison without becoming a prerequisite. Consequently, resolving the final scoped case must continue to auto-clear and unlock exactly as it does before this data extension.

Acceptance for this wire:

1. All ten definitions return complete localized completion/performance records.
2. Identical public summaries always produce identical score, target and grade results.
3. Scores below target still produce `CLEARED` and the same monotonic unlock update.
4. Grades use the highest threshold not greater than the public score.
5. Player-facing strings contain no raw IDs, internal enum tokens or private truth.
6. Production code contains one generic evaluator and zero stage-number-specific performance branches.
7. Existing Stage 2 final-case auto-unlock and Stage 10 Grand Reserve completion regressions remain green.

## Twenty real expansion artifacts

The MVP adds `artifact_061` through `artifact_080`, two introduced by each stage. Each expansion spec must have a unique runtime ID and visual signature plus meaningful inspection, repair and auction profiles. It may reuse a proven base mesh only when its material/scale/trim/detail combination, observable, repair tradeoff and bidder behavior are materially distinct. ID aliases and identical copied profile blobs are invalid.

Required expansion fields include:

- normal ArtifactSpec catalog fields;
- localized `inspectionObservable`;
- `repairProfile` with compatible tool options, tolerance, intervention tradeoff and cost pressure. The current single-tool workbench treats `requiredTools` as an allowed-alternatives list: the player must equip at least one listed tool, and the UI must expose those tools by friendly name;
- `auctionProfile` with bidder interests, condition sensitivity, provenance/disclosure scrutiny and reserve strategy.

The generic Repair action must be able to reach the authored fault contract. When `repairProfile.repairableDamages` is present it is authoritative; otherwise a non-empty expansion `repairProfile` exposes the spec's `possibleFaults`. At least one possible fault must therefore intersect the runtime repairable set, and every listed repair tool must exist in the tool registry. A profile that is valid JSON but unreachable from Repair fails the content gate.

This produces 80 playable ArtifactSpecs. It does not create twenty new authored story cases.

## Seven-percent difficulty rule

The multiplier is consumed exactly once by each applicable subsystem.

It may increase:

- restoration resource/cost pressure, damage consequence and precision tolerance;
- risky investigation consequence and advanced-tool pressure;
- auction condition sensitivity, provenance/disclosure scrutiny and reserve-miss pressure.

It must never alter:

- canonical truth or the correct hypothesis;
- evidence SUPPORT/REFUTE strength, independence or clue count;
- base/hidden true value;
- permanent earned rewards, bidder cash, ending conditions or RNG seed.

Stage difficulty must not make evidence prose less informative. Difficulty comes from decisions and resource pressure, not withholding reasoning information.

## Profile and run-save contract

Persistent profile and current run are separate.

Profile minimum:

- `schema_version`
- `highestUnlockedStage` (Stage 1 always unlocked)
- `clearedStages`
- `stageBest`

Clearing Stage N updates the profile monotonically and idempotently: add N, unlock at most N+1, and keep the greater prior/current best score. A replay can never relock a stage or reduce a best score.

Run save additionally records `currentStage`, current case and stage-run state. `CONTINUE` restores the run. `NEW GAME` resets the run but preserves the profile. `STAGE SELECT` exposes only stages at or below `highestUnlockedStage`.

Both stores use temp → validation → backup → replace and must pass six interruption points. Invalid current and backup files return an explicit failure without silently resetting memory.

## Illustrated Case UI v1

The MVP uses one data-driven illustrated dossier for all cases, with full authored evidence graphs for sixteen cases and a compact playable projection for the remaining ten.

Sixteen local SVG pictograms form the shared vocabulary: briefing, core question, objective, artifact, document, NPC, reference, generic clue, hypothesis, support, refute, tool, risk, locked, citation and report.

At 1280×720:

- the first viewport has no explanatory paragraph longer than two lines and targets at most 180 visible Korean explanatory characters;
- the three header tiles each show one title and one compact summary line;
- collapsed evidence cards show an icon, short title and state badges, with zero body lines;
- Click/Enter/Space selects a card and shows one stable shared detail panel; keyboard focus alone does not expand layout;
- locked cards show only an unlock reason and never leak hidden observations;
- hypothesis and report areas use illustrated cards and an independence `0/3`–`3+/3` summary;
- support/refute, risk, lock and reliability remain distinguishable through shape plus a short label, never color alone;
- every control remains keyboard reachable and locale refresh preserves the current case/detail selection.

Long authored prose is retained in the detail layer rather than deleted.

## Stage 2 authored-v2 tranche

Stage 2 no longer uses the generic fallback for `leave_patina`, `estate_compass` or `pawn_watch`. Each case has three contested localized hypotheses and a dependency graph spanning all four canonical source kinds: artifact observation, document, NPC statement and independent reference. Every source participates in at least one SUPPORT or REFUTE link, evidence is separated into five or more independent groups, and the strongest single source remains insufficient for a STRONG report.

The intended conclusions are natural patina, misdated provenance and period repair respectively. Stage 2 applies exactly one LOW-risk investigation in each case; `pawn_watch` alone adds one HIGH-risk internal examination. Tool gates use the existing registry and the unchanged Stage 2 difficulty multiplier `1.07`. Duplicate discovery, rejected citation and repeat resolution are authority-, telemetry- and RNG-neutral.

One generic authored-evidence bridge may carry optional `public_clue_id: PROVENANCE` only on a source that independently establishes public provenance. First discovery appends the existing public clue exactly once; duplicate discovery and save/reload add nothing. The raw adapter field, canonical hypothesis and hidden truth never enter the player-facing dossier. This bridge changes neither the auction formula nor bidder behavior, but lets the already-frozen public auction reason path change from provenance uncertain to provenance strong when the player has actually established it.

`estate_compass` now issues `artifact_011` (`model_11.obj`, base value 300) rather than the unrelated `artifact_009` ceramic vase. The campaign reward spec and `story_artifact_05` base spec are the only corrected bindings. Already-issued legacy `artifact_009` instances keep their UID, ledger and saved state without migration; fresh issuance uses `artifact_011`. The only accepted economy delta is the deterministic `262 → 300` spec-derived input for that newly issued relic.

The Stage 2 suite freezes all three authored definitions, the three previously authored cases, campaign identity/reward arrays, dependency/tool/risk behavior, report evaluation, once-only resolution, public provenance consequence, bilingual privacy, legacy issuance compatibility and the absence of case-ID branches. Passing that suite was a content milestone, not completion of the campaign-wide authored migration.

Authored `resolution.outcome_rules` are an ordered runtime authority rather than dead metadata. The generic evaluator applies `masterful -> credible -> mistaken -> reviewed_with_mentor` in authored order, with all declared correctness, citation, independence, net-support and required-source conditions combined by AND. A zero threshold means no constraint. One citation remains a valid submission boundary so an under-supported report can teach through mentor feedback; zero citations fail closed. Cases without authored rules retain the pre-existing legacy strong/plausible evaluator exactly.

## Stage 3 authored-v2 tranche

Stage 3 now resolves `garage_lamp`, `telephone_trace` and `early_camera` through the same authored-v2 normalizer, evidence ledger, resolver and illustrated dossier. The three cases respectively distinguish a genuine period electrical repair, a genuine telephone with a documented modern safety intervention and a later display-camera reproduction. Every case has three contested localized hypotheses, all four source kinds, at least five independent groups, both SUPPORT and REFUTE links, dependency edges and a one-source ceiling below credible.

Risk remains sparse and readable. `garage_lamp` has exactly one LOW-risk screwdriver route and no HIGH-risk source. `telephone_trace` has one LOW material-scan route and one HIGH precision-disassembly route. `early_camera` has one LOW material-scan route and one HIGH UV route. Safe NONE evidence stays the majority in every case, and no single tool solves all risky Stage 3 paths. Exactly one strong document per case may grant the existing public `PROVENANCE` clue.

All three cases use the ordered authored thresholds: masterful requires four citations from four independent groups at the authored net threshold, credible requires three from three, an evidence-backed wrong report requires at least two citations for mistaken, and every weaker submission falls back to mentor review. No Stage 3 case-ID branch or new scoring vocabulary is introduced.

`telephone_trace` now issues `artifact_015` (`model_15.obj`, base value 376), matching the Orchard table telephone, instead of the unrelated `artifact_010` mechanical toy (base value 281). Only `story_artifact_08.baseSpecId` and the campaign reward binding change. Fresh issuance therefore has an exact +95 base input before deterministic artifact-profile derivatives; already-issued legacy `artifact_010` instances preserve their UID, ledger and saved state without migration. Cash, reputation, case order, NPC/doc bindings, save schema, auction formulas and RNG remain unchanged.

## Player-safe authored presentation metadata bridge

The generic authored normalizer now carries six optional presentation concepts without making them gameplay authority: localized artifact display name, localized short source name, validated NPC portrait presentation, localized unlock action-and-target copy, localized citation locator and localized short observation. Source display names and citation labels remain separate fields so a compact card title cannot silently replace a report citation. Missing optional copy falls back to the bound ArtifactSpec display name, localized source-kind/action/target labels and the source title; incomplete bilingual dictionaries and identifier-shaped copy fail closed to those safe fallbacks.

The dossier consumes only the sanitized presentation bundle. A locked card and its detail expose the localized action and target guidance only; they do not expose the observation, source/reference identifiers, prerequisites, tool identifiers or citation locator. The locator appears only after discovery and then only in discovered detail and the cited-report tooltip. An NPC portrait is supplied only when the mapped local SVG advertises the approved sclera/iris/pupil/highlight parts. Legacy dot-eye or unmapped campaign NPC art yields no portrait payload and the unlocked card uses the generic NPC icon.

The bridge changes no evidence relation, risk level, unlock requirement, resolution threshold, save/profile data, economy, auction state or RNG. Locale switching and dossier rendering are presentation-only. The established isolated authored-presentation suite remains **11/11 PASS**; Stage 6's new case-NPC and pair-render presentation is separately frozen by the **12/12 PASS** Stage 6B visual-identity suite. These verify the covered normalized and rendered surfaces, while raw routing IDs retained inside public DTOs remain a separate open audit item outside the whitelist-only artifact render DTO.

## Legacy unresolved authored-save canonicalization

When a previously projected case becomes authored-v2, only an unresolved saved case state is canonicalized against the current definition. Discovered and cited evidence membership is intersected with current evidence IDs, deduplicated and restored in current authored order; invalid draft hypotheses and stale unresolved result fields are cleared. The operation is idempotent across repeated save/reload. A resolved historical case remains byte-exact even when it contains pre-authored identifiers.

Canonicalization does not rewrite the issued artifact, story/spec identity, issue/sale ledger, economy, RNG, public clues, repair state, auction state, tutorial state, telemetry or save schema. The two formerly projected Stage 4 states can rediscover, cite and resolve after normalization without cross-case evidence contamination. The isolated migration suite is **5/5 PASS**.

## Stage 4 authored-v2 tranche

Stage 4 (`Paper Trails`, multiplier `1.225043`) keeps its canonical order: `false_invoice`, `mislabelled_collection`, `observatory_instrument`. The latter two now resolve as hash-locked authored-v2 definitions through the same generic registry, public-state, discovery and report paths. The authored validator is **PASS**, and the Stage 4 load contract requires both new case IDs to resolve with **fallback count 0**; no case-ID gameplay or dossier branch is permitted.

`mislabelled_collection`, titled *The Borrowed Accession Label*, binds `story_artifact_11` to `artifact_018`, Rook Slide Projector R, Model 117. Its canonical conclusion is a genuine projector with a swapped accession label, not a correctly matched collection label and not a later composite with a false identity. Its six independent sources are exactly two artifact observations, two documents, one Hana Mire statement and one fictional `history_18` reference. Five sources are NONE risk and one is LOW risk behind `material_scanner`; none is HIGH risk. D21 is a model catalog and explicitly not provenance. D22 is the sole strong-document `PROVENANCE` source.

`observatory_instrument`, titled *Compass on the Meridian*, binds `story_artifact_12` to `artifact_011`, Kestrel Compass K, Model 110. It is a meridian-and-azimuth reference compass, not a telescope. The canonical conclusion is a genuine period instrument with a period pivot repair, rather than an untouched compass or later display assembly in an old case. Its six independent sources use the same exact 2/2/1/1 source-kind split with Hana Mire and fictional `history_11`. Four sources are NONE risk, the dial material route is LOW risk behind `material_scanner`, and the pivot-cap route is HIGH risk behind `precision_screwdriver`. D23 is the sole strong-document `PROVENANCE` source; D24 documents service but is explicitly not provenance.

Both new cases include SUPPORT and REFUTE relations, real dependency edges, a safe-source majority and a one-source ceiling below credible. Their ordered outcome contract is exact: correct 4 citations/4 independent groups/net 4 yields `masterful`; correct 3/3/net 3 yields `credible`; an incorrect conclusion with two citations yields `mistaken`; weaker non-empty submissions fall back to `reviewed_with_mentor`, while zero citations fail closed. Discovery of each sole provenance document may add the existing public clue once; duplicate discovery must add nothing.

## Stage 5 authored and visual-identity tranche

Stage 5 (`Collector's Eye`, multiplier `1.31079601`) keeps `collector_promise → three_cameras → shadow_camera` in canonical order and now has fallback count 0. `collector_promise` binds `story_artifact_13` to `artifact_021`; `three_cameras` binds `story_artifact_14` to `artifact_033`. Each new case has five independent sources with the exact split two artifact observations, one document, one NPC and one reference. Four sources are NONE risk and one is LOW risk; the respective gated routes use `precision_screwdriver` and `material_scanner`, and neither case adds a HIGH-risk action. Document 25 and document 27 are respectively the sole public `PROVENANCE` bridges. The existing `shadow_camera` definition, risk pressure, public clues and historical save behavior remain exact, including the deliberate decision not to backfill provenance.

The Stage 5A gameplay/save gate is **11/11 PASS**; unresolved authored migration is **5/5 PASS**, the Stage pressure runtime and baseline suites are **5/5 PASS**, and the Shadow Camera exact-preservation suite is **10/10 PASS**. These tests preserve campaign order, fresh issuance, historical issued artifacts, ledger/economy/RNG state and the generic ordered outcome path.

Stage 5B adds a whitelist-only ten-field artifact render DTO: `specId`, `meshPath`, `scale`, `materialPath`, `palette`, `metallic`, `roughness`, `trim`, `detail` and `recipe`. The allowlisted recipe distribution across all eighty specs is `DEFAULT 78 / TYPEWRITER_CIPHER 1 / SEXTANT 1`; unknown recipes fail closed instead of silently rendering a generic band. Artifact 069 keeps its typewriter silhouette and renders one cipher keyline, nine third-row keys, two paired glyphs and two filed stops. Artifact 070 uses the repo-native `sextant.obj` and renders eleven arc-degree marks plus a vernier, index mirror and thirty-degree wear sector, with no compass reuse. The isolated Stage 5B visual-identity suite is **10/10 PASS**.

Victor Hale and Lena Falk are separately approved case-NPC mappings outside the fixed auction/shop/bidder/event roster. Their 256×320 SVG V2 busts have complete sclera, iris, pupil and highlight systems, distinct faces, hair, outfits and role accessories. Both remain recognizable in the actual dossier's minimum 96×120 texture slot and never fall back to the generic NPC icon.

## Stage 6 authored and pair-keyed visual tranche

Stage 6 (`Shadow Marks`, multiplier `1.4025517307`) keeps `shadow_gauge → shadow_clock → shadow_music_box` in canonical order and now has fallback count 0. Fresh issuance binds the cases to `artifact_050`, `artifact_031` and `artifact_035` respectively; historical issued instances, their ledgers and unrelated save authority remain exact.

Every Stage 6 case has three contested localized hypotheses and six independent sources with the exact split two artifact observations, two documents, one NPC and one reference. NONE/LOW/HIGH risk is exactly `4/1/1` in each case. Their ordered outcome contract is the common authored ladder: correct 4 citations from 4 independent groups yields `masterful`, correct 3/3 yields `credible`, a wrong conclusion with at least two citations yields `mistaken`, and every weaker non-empty report falls back to `reviewed_with_mentor`. Stage 6A authored/binding/save coverage is **13/13 PASS** and its isolated economy contract is **4/4 PASS**.

Stage 6B adds two pair-keyed visual identities without changing the spec-wide defaults. `story_artifact_16 + artifact_050` alone receives the `GAUGE` recipe and `gauge.obj`; `story_artifact_18 + artifact_035` alone receives `MUSIC_BOX` and `music_box.obj`. Legacy story/spec pairings and spec-only calls keep their established default mesh/recipe, and both fresh overrides consume the whitelist-only instance RenderDTO. Exact live mesh and recipe-node contracts, deep-copy/privacy boundaries and generic-trim absence are **12/12 PASS**.

Hana Mire, Mara Venn and Iris Bell use distinct 256×320 SVG V2 concerned busts with visible sclera, iris, pupil, highlights, brows, expressions and role accessories. All three remain recognizable in the actual 96×120 `CaseNpcSourcePortrait` slot and in the large three-up review. A hidden/headless Godot editor import-raster refresh is required before captures after any portrait-source change; the actual framebuffer gate must reject a stale imported texture even when source metadata validation passes.

Authored-v2 coverage is therefore **16/26**, with **10** playable projected cases remaining. The canonical local Stage 7 audit identifies a two-case tranche as the active next authored batch; its case IDs are intentionally not named here until the reviewed content decision freezes them.

## Characterful portrait/dialogue UI

Auction, shop and activated-event screens use characters as readable interface state, not as detached decoration. The fixed recurring auction/shop/bidder/event roster contains exactly eighteen locally authored bust portrait SVGs, separate from the sixteen case pictograms and separately approved case-NPC portraits:

- one recurring auctioneer;
- one recurring artifact shopkeeper;
- one unique portrait for each of the twelve existing bidder identities;
- four reusable event characters.

Every base portrait includes a distinct face, hairstyle, upper-body outfit silhouette and signature accessory. The face must remain recognizable in the actual 220–300 px portrait rail: a big-eyed chibi treatment uses visible sclera, iris/pupil, highlight, brows, nose/mouth and a readable expression. Dot/slit eyes, accessory-only differentiation and faces that disappear at runtime size fail visual QA. A generic `CharacterProfile + CharacterCue -> PortraitDialoguePanel` renderer supplies `NEUTRAL`, `POSITIVE` and `NEGATIVE` expression layers and role-specific cues. Bidder-, event-, case- and stage-specific renderer branches are invalid.

The semantic cue vocabulary is:

- auctioneer: `INTRO`, `CALL`, `SOLD`, `NO_SALE`;
- bidder: `WATCH`, `BID`, `DROPOUT`, `WON`;
- shopkeeper: `WELCOME`, `OFFER`, `PURCHASE_OK`, `PURCHASE_FAIL`;
- event character: `REQUEST`, `REACTION_POS`, `REACTION_NEG`.

At 1280×720, auction presentation follows one fixed gameplay hierarchy: the dominant current price or SOLD/NO SALE state and its one primary action come first, the active/final bidder portrait and at most two public reason chips come second, and the recurring auctioneer comes last. The auctioneer never repeats the price in dialogue. The shop keeps its shopkeeper beside the artifact list. An activated event shows its character beside the situation and choices. Portrait cues never steal keyboard focus or delay authoritative resolution, and repeated automatic auction cues are debounced.

Speech is normally one Korean line, never more than two lines, targets 24 characters and has an approximate hard cap of 44 characters. Portrait expression may replace transient emotional flavor, but never replaces critical labels such as price, reserve state, bidder dropout, purchase-failure reason, risk, reliability, event result or gameplay modifiers.

Character identity remains stable across all ten stages. Deterministic early (Stages 1–3), mid (4–7) and late (8–10) palette/accessory accents may vary wardrobe without pretending that a recolor is a new person. Locale changes and save/reload derive the current cue again from authoritative auction, shop or event state; transient expressions are not persisted.

## Card-driven repeated core UI

The screens players revisit most often use icon cards plus one shared detail area instead of long scrolling text lists. Inventory shows at most eight relic cards in a `2 × 4` grid and paginates without scrolling. Each card is limited to name, public value and one damage/clue badge line; linked case and expanded public condition move to the single detail panel. Selecting a card changes presentation state only, while the separate Inspect primary remains the sole route that changes the active workpiece.

Authentication shows at most six compact evidence cards in a `2 × 3` grid and exactly six icon hypothesis cards in a `3 × 2` grid. Evidence cards expose a short public title, source icon, support/refute/observed relation and reliability; the selected observation is limited to two lines in one detail panel. A hypothesis press changes only the established draft `playerHypothesis`; the single Accept primary is disabled for Unknown and remains the only commit action.

All twenty-five upgrades remain reachable through five no-scroll pages of at most six cards in a `2 × 3` grid. Every card contains an icon, localized name, cost/owned state and one-line localized effect summary. Selection opens one two-line-maximum detail panel and never purchases. Only the one selected-detail Buy primary may charge money, add ownership and apply the effect; duplicate purchase remains blocked.

Korean/English locale refresh, page movement and card/detail selection on all three screens preserve authoritative state and RNG. Player-facing copies contain no raw IDs, snake-case fields, localization keys or private truth.

## Contextual Stage 1 guide

Stage 1 owns one data-driven six-step guide: investigate → cite → report → repair → list → auction. It is not a separate tutorial scene and it never advances from a Skip or Next button. Only the corresponding successful authoritative game action completes a step.

The visible guide is a compact illustrated rail: one existing pictogram, `Guide N/6`, one short title and one instruction line. It resolves the nearest visible and enabled control from public route IDs, highlights that control without changing its authority, and can route through existing navigation where the action is on another screen. A disabled report points to hypothesis/citation preparation; repair first points to the required tool when the wrong tool is equipped, then to the repair action.

Full completion persists in the profile. An abandoned partial run restarts at step one when a fresh Stage 1 run begins so guidance cannot point into state that no longer exists. The Stage Select Help action explicitly resets and replays the guide; Stage 2–10 never show it automatically. The public API exposes localized title/text/icon/targets only and never event triggers, internal step IDs or completion tokens.

## Player-controlled listing and causal auction feedback

Listing is a two-step decision, not an automatic `starting/reserve/disclosure` button.

Step one offers exactly three illustrated price plans derived from the visible appraisal:

- Fast: start 50%, reserve 60%;
- Balanced: start 60%, reserve 72%;
- High target: start 68%, reserve 82%.

Step two offers three claim strengths backed by the same public facts: Uncertain, Likely and Certain. These are different disclosure claims, not a weak-to-strong upgrade ladder. The screen shows only visible condition, investigation confidence and whether provenance was found, summarized as low/medium/high support plus one compact calibration risk such as overclaim, balanced claim or under-disclosure. It never reads `auctionProfile` tuning, canonical truth, true rarity/value, original-parts truth, bidder maximums or a sale probability to recommend an answer.

The auction uses a base random stream fixed by run/day/lot identity; listing choices must not alter or reseed that stream. Price and disclosure therefore change bidder decisions only through their declared mechanics. Disclosure calibration compares the selected public claim strength with support derived exclusively from authoritative visible confidence, provenance and condition. Certain may help a well-supported lot but must be worse than a calibrated lower claim in a low-support fixture; Uncertain must likewise lose appeal when strong visible evidence is under-disclosed.

Every bidder/result may expose zero to two deterministic public reason chips from different categories. Price pressure has first priority for a no-sale where reserve exceeds the highest real bid, followed by provenance, condition and disclosure calibration. Chips explain the result and never cause it. A no-bid auction has hammer/final price zero while retaining its separate opening price. Flipping hidden truth while keeping all public inputs fixed must leave support hints, RNG variation and reason-chip sequence unchanged.

The final listing summary retains exactly three compact public causal badges in condition → provenance → disclosure order. The public pending-auction adapter derives intermediate bidder reasons from the already-frozen result without writing them into the canonical cue queue. Intermediate BID/DROPOUT screens show no more than two chips; the terminal screen deterministically selects exactly one primary aggregate reason. These presentation adapters must leave the persisted cue queue, cue index, result, receipt, save schema and RNG state unchanged.

## Replay feedback and 1280×720 playability

Stage Clear remains a successful clear regardless of advisory target. It adds three compact illustrated replay axes, all computed from public run facts:

- Evidence: scoped case evidence/report performance;
- Preservation: visible condition, intervention and integrity results;
- Sale: public appraisal/listing/participation/sold-or-no-sale results.

The Evidence axis weights deliberate cross-checking above collection volume: `35%` discovered-evidence coverage plus `65%` unique cited independent-source coverage, clamped per scoped case. The Preservation axis uses `65%` recorded historical integrity plus `35%` mean visible surface/structural/mechanical condition. The Sale axis is unavailable when no scoped auction was attempted; otherwise it uses `65%` sold conversion plus `35%` sold net realization against the cached appraisal the player actually saw. It never divides by the player-controlled reserve, so lowering only the reserve cannot inflate the realization component.

The cached appraisal and visible condition snapshot are committed with the listing/sale record before a sold artifact leaves inventory. Replay scoring never recomputes appraisal from canonical truth and never reads authenticity truth, true rarity/significance/value or original-parts truth. An unavailable Sale axis renders as an em dash and is excluded from weakest-axis selection.

Each axis uses an existing pictogram, a short localized label and a 0–100 value. The weakest actionable axis supplies exactly one short improvement line. It cannot inspect hidden truth and it does not become a completion or unlock gate.

### Stage pressure telemetry

Save v6 adds a diagnostic record beneath `stageRunState`, separate from the three score axes. It counts only authoritative public actions: restoration actions and accrued restoration cost, unique repair-tool use, discovered evidence and applied public risk, listing preset, committed auction outcome, no-sale, sale and relist. Every event uses a durable action/transaction identity so preview, Continue, repeated Hammer and crash recovery cannot count it twice.

The public derived view reports restoration-cost pressure against the visible starting budget, risky-investigation rate/weight, listing-strategy shares, no-sale rate, relist count and tool concentration. None of these values affects score, completion, bidder resolution, RNG or unlocks. At clear, the view freezes beside the existing replay snapshot and locale changes only its labels. A pre-v6 partial or cleared run is never reconstructed from hidden history: telemetry is marked unavailable until a fresh selected-stage run begins.

The Stage Clear card may add one icon-led diagnostic line only. It can say that risky clues were taken, how many tool types were used, that tool use was concentrated, or that a relist occurred. It may not show hidden truth/value, undiscovered evidence, bidder thresholds, canonical hypotheses or raw tuning ratios.

The authored Stage 1/5/10 pressure contract is now fixed as a sparse relative curve rather than an all-actions penalty. Its diagnostic weight per available evidence action is `0.466667 → 0.819248 → 1.149037`. Stage 5 adds only one LOW repair-trace risk to each of `collector_promise` and `three_cameras`; Stage 10 keeps five of eight fallback observations safe and assigns exactly two LOW plus one HIGH risk. The two introduced artifacts within Stage 5 and within Stage 10 have disjoint allowed `requiredTools` sets, so one shared tool cannot solve both new repair profiles. This content contract does not change the `1.07^(stage-1)` multiplier, the three replay axes, resolver, bidder AI, auction probability or save schema.

The paired non-Grand-Reserve auction control remains a measurement boundary: across 64 common seeds FAST/BALANCED/HIGH sell `64/53/45` times at Stages 1, 5 and 10. That controlled equality exposed a separate auction Stage-sensitivity issue and was not tuned inside the authored-risk/tool patch.

The completed auction audit freezes one narrowly bounded correction. Favorable disclosure bonuses are Stage-independent; unfavorable disclosure and reserve pressure continue to use full Stage difficulty. Only the negative condition/provenance public support-gap factors use `min(difficulty_multiplier, 1.66)`. Bidder budgets/AI, `.18/.08` base coefficients, listing presets, the three replay axes, save authority and RNG remain unchanged. The final paired audit covers 7,776 trials plus 162 repeat-determinism checks: all five strict gates pass, Stage 1/5/10 aggregate sold rates are monotonic, Stage 10 keeps FAST/BALANCED/HIGH viable at `94.7977% / 68.3805% / 50.1730%`, HIGH-support drift is zero and `NO_SALE → SOLD` reversals are zero. Auction tuning is frozen; restoration cash deduction and relist friction remain deferred until live telemetry demonstrates that either is needed.

## Final Journey presentation

Stage 10 does not end in a text dump. Final selection presents at most six eligible illustrated lot cards, requires exactly three selections and keeps one Begin primary visible without scrolling. The ending view uses one hero summary, the three canonical public replay axes, three selected-lot cards and one terminal public reason chip. Postgame uses one hero summary, exactly five ending cards, Stage Select/New Game/Credits actions and collapsed credits. These views preserve ending, profile, save and RNG authority across Korean/English refresh and introduce no eleventh stage.

At 1280×720, in Korean and English, the representative investigation, repair, listing and auction screens must keep one primary action visible, keep the guide rail and portrait dialogue clear of that action and critical prices, open at most one expanded detail area, keep speech to two lines or fewer, and have no clipped button label or off-viewport required control. This is a playability gate, not optional polish.

The current isolated hidden/background run is **68/68 PASS** under headless density QA and **70/70 PASS** for the actual OpenGL capture set with `heldArtifactsCreated=false`: 68 captures are 1280×720, while captures 57 and 58 remain two complete 1800×480, 10×4 sheets covering all **80/80 ArtifactSpecs**. All 70 hashes match the original-resolution manual review with `PASS_ORIGINAL_RESOLUTION`. In addition to the Stage 5 dossier, portrait and 069/070 identity views, the set includes six Stage 6 KO/EN report-ready dossiers, three actual 96×120 Hana/Mara/Iris detail views, their large three-up, and unobstructed fresh gauge and music-box pair renders. Compact source/citation ellipses retain differentiating meaning; all six source cards, three hypotheses, report action, header statistics and all eight navigation controls remain present in the covered Stage 6 flow. This is a source/runtime visual milestone, not a human playtest or completion declaration.

After these source gates pass, fresh actual Godot viewport captures cover the representative flows. The next human playtest records: unaided Stage 1 completion and block points; whether players reconsider listing choices; whether they can state the real auction cause from reason chips; whether a low result changes the next run's action; and how long players stop to read dossier, repair, listing and auction screens. Automated PASS alone cannot answer these questions.

## MVP freeze gates

1. M1 integrity, three authored-v2 contrast cases, visible-policy comparison and run-save crash tests pass.
2. All ten stages and twenty expansion artifacts validate without hardcoded stage gameplay branches.
3. Profile unlock/select/new-game/reload/monotonic-best behavior and profile crash tests pass.
4. Seven-percent scaling is deterministic, single-application and truth/evidence/value private.
5. Illustrated UI density, interaction, accessibility and legacy fallback tests pass with background/headless visual evidence.
6. All eighteen non-placeholder, big-eyed portraits remain face-legible at in-game size, pass a freshly rendered 1280×720 contact-sheet review, and the generic portrait/dialogue renderer produces the correct auction-entry/bid/dropout/sale, shop-entry/offer/success/failure and event-request/result cues without hiding critical state in an expression alone.
7. The six-step Stage 1 guide follows real enabled controls, advances only from authoritative actions, persists/replays safely and fits the 1280×720 KO/EN density contract.
8. All six controlled listing/auction causal gates pass: common RNG stream; listing-independent RNG consumption; low/mid/high support calibration; actual price/disclosure outcome differences; zero-price no-bid semantics; public-only deterministic reason chips.
9. Stage Clear shows public-only Evidence/Preservation/Sale replay feedback and one actionable weakest-axis line without changing clear or unlock authority.
10. Save-v6 stage pressure telemetry records repair/investigation/listing/auction actions exactly once, freezes on clear, fails closed when malformed and leaves the established three-axis score and RNG unchanged.
11. Stage 1/5/10 pressure audits enforce the sparse `0.466667 → 0.819248 → 1.149037` authored-risk curve, disjoint same-stage repair-tool routes, stable paired auction controls and at least two viable listing strategies before any cash-cost or relist-fee tuning is introduced.
12. The frozen auction sensitivity contract passes its 7,776-trial budget-stratified audit with monotonic Stage pressure, three viable Stage 10 listing strategies, protected high-support play and zero favorable outcome reversal.
13. Inventory, Authentication and Upgrades pass the compact-card, pagination, localization, raw-token, single-primary and exact authority/RNG boundary suites.
14. Final selection, Ending and Postgame pass the illustrated low-text journey contract in Korean and English without changing Stage completion or ending authority.
15. All three Stage 2 cases resolve through authored-v2 without projection fallback, preserve the four-source evidence contract, enforce their exact LOW/HIGH risk routes, bridge proven provenance once into public auction reasons and preserve pre-patch Estate Compass saves.
16. All three Stage 3 cases resolve through authored-v2 without projection fallback, enforce their distinct risk/tool and ordered-outcome contracts, expose provenance only through the one authored document per case and preserve pre-patch Telephone Trace saves while fresh issuance uses `artifact_015`.
17. The player-safe authored metadata bridge preserves artifact/source/portrait/action-target/locator/observation presentation, locked and discovery-timed privacy, bilingual fallbacks and authority mutation-zero across all sixteen authored cases.
18. Legacy unresolved authored states canonicalize to current ordered evidence membership idempotently, preserve resolved history and every unrelated authority domain, and allow newly authored cases through Stage 6 to resume without cross-case evidence.
19. Stage 4 resolves `false_invoice` then the two new authored cases with fallback count 0; the new cases preserve their exact artifact/story identities, six-source graphs, risk/tool counts, sole-document provenance bridges and ordered 4/4 → 3/3 → wrong+2 → mentor outcome ladder.
20. Stage 5A resolves all three cases through authored-v2 with fallback count 0, preserves the exact two new five-source/LOW-risk contracts and the pre-existing Shadow Camera pressure, provenance and save behavior, and keeps fresh versus historical issuance isolated.
21. Stage 5B keeps the artifact render DTO whitelist-only and mutation-free, fails unknown recipes closed, renders the exact 069/070 signature details, keeps Victor/Lena face-legible at 96×120 and provides uncropped actual-framebuffer coverage for all 80 ArtifactSpecs.
22. Stage 6A resolves all three Shadow Mark cases through authored-v2 with fallback count 0, preserves the exact `A2/D2/NPC1/REF1`, `4/1/1` risk and ordered outcome contracts, binds fresh artifacts to 050/031/035 and keeps historical saves/economy isolated.
23. Stage 6B confines `GAUGE` and `MUSIC_BOX` to their exact story/spec pairs, keeps legacy and spec-only rendering unchanged, keeps Hana/Mara/Iris face-legible at actual 96×120 after the import-raster gate, and passes 68/68 density plus 70/70 original-resolution-reviewed actual captures including both 80-spec sheets.
24. Existing core, campaign, ending, economy and authored-case regressions remain green.

Passing these gates means a **technical MVP source milestone**, not a finished game. Human pacing/usability/balance playtests, the remaining authored-v2 migration, broader polish and release verification still remain. `.exe`, `.pck`, `.zip`, `.7z` and `.rar` artifacts stay prohibited until a new explicit user instruction.
